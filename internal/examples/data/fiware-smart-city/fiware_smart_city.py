#!/usr/bin/env python3
"""
FIWARE Smart City & Digital Twin Control Center for Gubernator (gbnt)
Integrates with:
  - FIWARE Orion Context Broker (NGSI-v2 API on port 1026)
  - FIWARE IoT Agent for Ultralight 2.0 (Northbound 4041 / Southbound 7896)
  - MongoDB 6.0 Context Store
"""

import json
import math
import os
import random
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

ORION_URL = os.environ.get("ORION_URL", "http://orion:1026")
IOTA_NORTH_URL = os.environ.get("IOTA_NORTH_URL", "http://iot-agent:4041")
IOTA_SOUTH_URL = os.environ.get("IOTA_SOUTH_URL", "http://iot-agent:7896")
FIWARE_SERVICE = os.environ.get("FIWARE_SERVICE", "smartcity")
FIWARE_SERVICEPATH = os.environ.get("FIWARE_SERVICEPATH", "/")
API_KEY = os.environ.get("FIWARE_API_KEY", "4jggokgpepnvsb2uv4s40d59ov")
PORT = int(os.environ.get("PORT", "8080"))

state_lock = threading.Lock()
sim_stats = {
    "orion_connected": False,
    "orion_version": "connecting...",
    "iota_connected": False,
    "iota_version": "connecting...",
    "updates_sent": 0,
    "ultralight_frames_sent": 0,
    "last_update_ts": "",
    "streetlight_mode": "ON",       # ON, ECO, OFF
    "streetlight_dimming": 100,     # 0..100 %
    "traffic_override": "AUTO",     # AUTO, GREEN_WAVE, SPEED_LIMIT_50
    "air_alert_mode": "NORMAL",     # NORMAL, LOW_EMISSION_ZONE_ACTIVE
}

INITIAL_ENTITIES = [
    {
        "id": "urn:ngsi-ld:WeatherObserved:Madrid-Sol-01",
        "type": "WeatherObserved",
        "name": {"type": "Text", "value": "Puerta del Sol Meteorological Station"},
        "district": {"type": "Text", "value": "Centro"},
        "temperature": {"type": "Number", "value": 23.4},
        "relativeHumidity": {"type": "Number", "value": 46.0},
        "atmosphericPressure": {"type": "Number", "value": 1016.2},
        "windSpeed": {"type": "Number", "value": 12.5},
        "uvIndex": {"type": "Number", "value": 6.0},
        "location": {
            "type": "geo:json",
            "value": {"type": "Point", "coordinates": [-3.7038, 40.4168]},
        },
    },
    {
        "id": "urn:ngsi-ld:AirQualityObserved:Madrid-Castellana-01",
        "type": "AirQualityObserved",
        "name": {"type": "Text", "value": "Paseo de la Castellana Air Quality Node"},
        "district": {"type": "Text", "value": "Chamartin"},
        "no2": {"type": "Number", "value": 28.5},
        "pm25": {"type": "Number", "value": 11.2},
        "pm10": {"type": "Number", "value": 21.8},
        "co2": {"type": "Number", "value": 412.0},
        "airQualityIndex": {"type": "Number", "value": 34},
        "airQualityLevel": {"type": "Text", "value": "GOOD"},
        "lowEmissionProtocol": {"type": "Text", "value": "NORMAL"},
    },
    {
        "id": "urn:ngsi-ld:TrafficFlowObserved:M30-Norte-01",
        "type": "TrafficFlowObserved",
        "name": {"type": "Text", "value": "M-30 Northern Ring Road Sensor #01"},
        "roadName": {"type": "Text", "value": "Calle 30 - Nudo Norte"},
        "intensity": {"type": "Number", "value": 1420},
        "occupancy": {"type": "Number", "value": 42.5},
        "averageVehicleSpeed": {"type": "Number", "value": 78.0},
        "congested": {"type": "Boolean", "value": False},
        "signalControlMode": {"type": "Text", "value": "AUTO"},
    },
    {
        "id": "urn:ngsi-ld:Streetlight:GranVia-01",
        "type": "Streetlight",
        "name": {"type": "Text", "value": "Gran Via Smart LED Corridor Group #01"},
        "status": {"type": "Text", "value": "ok"},
        "powerState": {"type": "Text", "value": "ON"},
        "illuminanceLevel": {"type": "Number", "value": 100},
        "powerConsumption": {"type": "Number", "value": 14.8},
        "lampTechnology": {"type": "Text", "value": "LED-SmartDim"},
    },
    {
        "id": "urn:ngsi-ld:SmartEnergyMeter:District-Solar-01",
        "type": "ThreePhaseAcMeasurement",
        "name": {"type": "Text", "value": "Municipal Solar PV & EV Charging Hub"},
        "totalActivePower": {"type": "Number", "value": 310.5},
        "solarGenerationKw": {"type": "Number", "value": 425.0},
        "gridFrequency": {"type": "Number", "value": 50.01},
        "batterySoc": {"type": "Number", "value": 84.0},
    },
]


def http_json(method, url, payload=None, headers=None, timeout=4.0):
    hdrs = headers.copy() if headers else {}
    data = None
    if payload is not None:
        if isinstance(payload, (dict, list)):
            data = json.dumps(payload).encode("utf-8")
            hdrs.setdefault("Content-Type", "application/json")
        elif isinstance(payload, str):
            data = payload.encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8", errors="replace")
        if raw.strip():
            try:
                return resp.status, json.loads(raw)
            except Exception:
                return resp.status, raw
        return resp.status, None


def check_services():
    try:
        st, body = http_json("GET", f"{ORION_URL}/version", timeout=2.5)
        if st == 200 and isinstance(body, dict):
            ver = body.get("orion", {}).get("version", "3.10.0")
            with state_lock:
                sim_stats["orion_connected"] = True
                sim_stats["orion_version"] = ver
    except Exception:
        with state_lock:
            sim_stats["orion_connected"] = False

    try:
        st, body = http_json("GET", f"{IOTA_NORTH_URL}/iot/about", timeout=2.5)
        if st == 200 and isinstance(body, dict):
            ver = body.get("libVersion", "1.22.0")
            with state_lock:
                sim_stats["iota_connected"] = True
                sim_stats["iota_version"] = ver
    except Exception:
        with state_lock:
            sim_stats["iota_connected"] = False


def bootstrap_fiware():
    """Creates initial NGSI-v2 entities in Orion and Ultralight service group in IoT Agent."""
    for ent in INITIAL_ENTITIES:
        try:
            http_json("POST", f"{ORION_URL}/v2/entities?options=upsert", payload=ent, timeout=3.0)
        except Exception:
            pass

    # Provision Ultralight 2.0 Service Group in IoT Agent
    svc_group = {
        "services": [
            {
                "apikey": API_KEY,
                "cbroker": ORION_URL,
                "entity_type": "Thing",
                "resource": "/iot/d",
            }
        ]
    }
    try:
        http_json(
            "POST",
            f"{IOTA_NORTH_URL}/iot/services",
            payload=svc_group,
            headers={
                "fiware-service": FIWARE_SERVICE,
                "fiware-servicepath": FIWARE_SERVICEPATH,
            },
            timeout=3.0,
        )
    except Exception:
        pass


def telemetry_loop():
    tick = 0
    bootstrapped = False
    while True:
        check_services()
        with state_lock:
            orion_ok = sim_stats["orion_connected"]
            light_mode = sim_stats["streetlight_mode"]
            light_dim = sim_stats["streetlight_dimming"]
            traffic_mode = sim_stats["traffic_override"]
            air_mode = sim_stats["air_alert_mode"]

        if orion_ok and not bootstrapped:
            bootstrap_fiware()
            bootstrapped = True

        if orion_ok:
            tick += 1
            wave = math.sin(tick / 6.0)

            # 1. Update WeatherObserved
            temp = round(23.0 + 2.5 * wave + random.uniform(-0.2, 0.2), 1)
            hum = round(45.0 - 4.0 * wave + random.uniform(-0.5, 0.5), 1)
            wind = round(11.0 + 3.0 * abs(wave) + random.uniform(-0.4, 0.4), 1)
            try:
                http_json(
                    "PATCH",
                    f"{ORION_URL}/v2/entities/urn:ngsi-ld:WeatherObserved:Madrid-Sol-01/attrs",
                    payload={
                        "temperature": {"type": "Number", "value": temp},
                        "relativeHumidity": {"type": "Number", "value": hum},
                        "windSpeed": {"type": "Number", "value": wind},
                    },
                )
            except Exception:
                pass

            # 2. Update AirQualityObserved
            base_no2 = 22.0 if air_mode == "LOW_EMISSION_ZONE_ACTIVE" else 34.0
            no2 = round(base_no2 + 6.0 * wave + random.uniform(-1.2, 1.2), 1)
            pm25 = round((9.5 if air_mode == "LOW_EMISSION_ZONE_ACTIVE" else 14.0) + 2.5 * wave + random.uniform(-0.5, 0.5), 1)
            aqi = int(max(15, min(120, round(no2 * 0.9 + pm25 * 1.1))))
            level = "GOOD" if aqi < 50 else ("MODERATE" if aqi < 80 else "HIGH")
            try:
                http_json(
                    "PATCH",
                    f"{ORION_URL}/v2/entities/urn:ngsi-ld:AirQualityObserved:Madrid-Castellana-01/attrs",
                    payload={
                        "no2": {"type": "Number", "value": no2},
                        "pm25": {"type": "Number", "value": pm25},
                        "airQualityIndex": {"type": "Number", "value": aqi},
                        "airQualityLevel": {"type": "Text", "value": level},
                        "lowEmissionProtocol": {"type": "Text", "value": air_mode},
                    },
                )
            except Exception:
                pass

            # 3. Update TrafficFlowObserved
            if traffic_mode == "GREEN_WAVE":
                intensity = int(1150 + 120 * wave + random.randint(-30, 30))
                speed = round(84.0 + 3.0 * wave + random.uniform(-1.0, 1.0), 1)
                occ = round(31.0 + 4.0 * wave, 1)
                congested = False
            elif traffic_mode == "SPEED_LIMIT_50":
                intensity = int(1380 + 150 * wave + random.randint(-40, 40))
                speed = round(48.5 + 1.5 * wave + random.uniform(-0.8, 0.8), 1)
                occ = round(48.0 + 5.0 * wave, 1)
                congested = False
            else:
                intensity = int(1520 + 280 * wave + random.randint(-50, 50))
                speed = round(71.0 - 12.0 * wave + random.uniform(-1.5, 1.5), 1)
                occ = round(46.0 + 14.0 * wave, 1)
                congested = occ > 55.0

            try:
                http_json(
                    "PATCH",
                    f"{ORION_URL}/v2/entities/urn:ngsi-ld:TrafficFlowObserved:M30-Norte-01/attrs",
                    payload={
                        "intensity": {"type": "Number", "value": intensity},
                        "occupancy": {"type": "Number", "value": occ},
                        "averageVehicleSpeed": {"type": "Number", "value": speed},
                        "congested": {"type": "Boolean", "value": congested},
                        "signalControlMode": {"type": "Text", "value": traffic_mode},
                    },
                )
            except Exception:
                pass

            # 4. Update Streetlight
            power_kw = round(14.8 * (light_dim / 100.0), 2) if light_mode != "OFF" else 0.0
            try:
                http_json(
                    "PATCH",
                    f"{ORION_URL}/v2/entities/urn:ngsi-ld:Streetlight:GranVia-01/attrs",
                    payload={
                        "powerState": {"type": "Text", "value": light_mode},
                        "illuminanceLevel": {"type": "Number", "value": light_dim if light_mode != "OFF" else 0},
                        "powerConsumption": {"type": "Number", "value": power_kw},
                    },
                )
            except Exception:
                pass

            # 5. Update SmartEnergyMeter
            solar_kw = round(410.0 + 45.0 * wave + random.uniform(-4.0, 4.0), 1)
            active_kw = round(295.0 + 25.0 * wave + power_kw, 1)
            soc = round(min(99.0, max(40.0, 82.0 + 6.0 * wave)), 1)
            try:
                http_json(
                    "PATCH",
                    f"{ORION_URL}/v2/entities/urn:ngsi-ld:SmartEnergyMeter:District-Solar-01/attrs",
                    payload={
                        "totalActivePower": {"type": "Number", "value": active_kw},
                        "solarGenerationKw": {"type": "Number", "value": solar_kw},
                        "batterySoc": {"type": "Number", "value": soc},
                    },
                )
            except Exception:
                pass

            # 6. Also send an Ultralight 2.0 frame to IoT Agent Southbound (port 7896)
            try:
                ul_payload = f"t|{temp}|h|{hum}|w|{wind}"
                http_json(
                    "POST",
                    f"{IOTA_SOUTH_URL}/iot/d?k={API_KEY}&i=weather001",
                    payload=ul_payload,
                    headers={"Content-Type": "text/plain"},
                    timeout=2.0,
                )
                with state_lock:
                    sim_stats["ultralight_frames_sent"] += 1
            except Exception:
                pass

            with state_lock:
                sim_stats["updates_sent"] += 5
                sim_stats["last_update_ts"] = time.strftime("%H:%M:%S")

        time.sleep(3.0)


DASHBOARD_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>FIWARE Smart City & Context Broker — Gubernator</title>
<style>
  :root {
    --bg: #0b1120;
    --card: #111827;
    --border: #1e293b;
    --text: #f8fafc;
    --muted: #94a3b8;
    --cyan: #00b4d8;
    --indigo: #6366f1;
    --emerald: #10b981;
    --amber: #f59e0b;
    --rose: #f43f5e;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: 'Inter', system-ui, -apple-system, sans-serif;
    background: var(--bg);
    color: var(--text);
    padding: 24px;
  }
  .header {
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
    padding-bottom: 20px;
    border-bottom: 1px solid var(--border);
    margin-bottom: 24px;
  }
  .title-wrap h1 {
    margin: 0;
    font-size: 22px;
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .badge-fiware {
    background: linear-gradient(135deg, #00b4d8, #0077b6);
    color: #fff;
    padding: 4px 10px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.5px;
  }
  .subtitle {
    color: var(--muted);
    font-size: 13px;
    margin-top: 6px;
  }
  .status-pills {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
  }
  .pill {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 999px;
    padding: 6px 14px;
    font-size: 12px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--emerald);
    box-shadow: 0 0 8px var(--emerald);
  }
  .dot.off { background: var(--rose); box-shadow: none; }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(310px, 1fr));
    gap: 16px;
    margin-bottom: 24px;
  }
  .card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 18px;
  }
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 14px;
  }
  .card-title {
    font-weight: 600;
    font-size: 15px;
  }
  .entity-urn {
    font-family: monospace;
    font-size: 11px;
    color: var(--cyan);
    margin-top: 3px;
    word-break: break-all;
  }
  .entity-type {
    background: rgba(99, 102, 241, 0.15);
    color: #818cf8;
    border: 1px solid rgba(99, 102, 241, 0.3);
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 4px;
    font-family: monospace;
  }
  .metrics-row {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 10px;
    margin-top: 10px;
  }
  .metric-box {
    background: rgba(15, 23, 42, 0.7);
    border: 1px solid #1e293b;
    border-radius: 8px;
    padding: 10px 12px;
  }
  .metric-label {
    font-size: 11px;
    color: var(--muted);
    text-transform: uppercase;
  }
  .metric-val {
    font-size: 18px;
    font-weight: 700;
    margin-top: 4px;
    color: #e2e8f0;
  }
  .controls {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    margin-top: 14px;
    padding-top: 12px;
    border-top: 1px solid var(--border);
  }
  button {
    background: #1e293b;
    color: #f8fafc;
    border: 1px solid #334155;
    border-radius: 6px;
    padding: 7px 12px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
  }
  button:hover {
    background: var(--cyan);
    color: #0b1120;
    border-color: var(--cyan);
  }
  button.active {
    background: var(--emerald);
    color: #0b1120;
    border-color: var(--emerald);
  }
  pre {
    background: #070b14;
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 14px;
    font-size: 12px;
    color: #38bdf8;
    overflow-x: auto;
    max-height: 360px;
    margin: 0;
  }
</style>
</head>
<body>
  <div class="header">
    <div class="title-wrap">
      <h1>
        <span class="badge-fiware">FIWARE NGSI-v2</span>
        Smart City & Digital Twin Context Broker
      </h1>
      <div class="subtitle">
        Powered by FIWARE Orion Context Broker (:1026) + IoT Agent Ultralight 2.0 (:4041/:7896) + MongoDB 6.0 on Gubernator
      </div>
    </div>
    <div class="status-pills">
      <div class="pill"><span id="orion-dot" class="dot"></span> <span id="orion-status">Orion Context Broker: ...</span></div>
      <div class="pill"><span id="iota-dot" class="dot"></span> <span id="iota-status">IoT Agent UL: ...</span></div>
      <div class="pill">NGSI Updates: <strong id="updates-count">0</strong> (<span id="last-ts">--:--:--</span>)</div>
    </div>
  </div>

  <div id="entities-grid" class="grid"></div>

  <div class="card">
    <div class="card-header">
      <div>
        <div class="card-title">Live NGSI-v2 Context Broker Payload (GET /v2/entities?options=keyValues)</div>
        <div class="entity-urn">Direct response from FIWARE Orion Context Broker container (http://orion:1026/v2/entities)</div>
      </div>
    </div>
    <pre id="raw-json">Loading NGSI-v2 entities from FIWARE Orion...</pre>
  </div>

<script>
async function sendActuator(action, value) {
  await fetch('/api/actuate', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({action, value})
  });
  await refreshState();
}

function renderEntityCard(ent, stats) {
  const type = ent.type;
  let metricsHtml = '';
  let controlsHtml = '';

  if (type === 'WeatherObserved') {
    metricsHtml = `
      <div class="metric-box"><div class="metric-label">Temperature</div><div class="metric-val">${ent.temperature?.value ?? '--'} °C</div></div>
      <div class="metric-box"><div class="metric-label">Humidity</div><div class="metric-val">${ent.relativeHumidity?.value ?? '--'} %</div></div>
      <div class="metric-box"><div class="metric-label">Wind Speed</div><div class="metric-val">${ent.windSpeed?.value ?? '--'} km/h</div></div>
      <div class="metric-box"><div class="metric-label">Pressure</div><div class="metric-val">${ent.atmosphericPressure?.value ?? '--'} hPa</div></div>
    `;
  } else if (type === 'AirQualityObserved') {
    metricsHtml = `
      <div class="metric-box"><div class="metric-label">NO₂ Concentration</div><div class="metric-val">${ent.no2?.value ?? '--'} µg/m³</div></div>
      <div class="metric-box"><div class="metric-label">Fine Particles PM2.5</div><div class="metric-val">${ent.pm25?.value ?? '--'} µg/m³</div></div>
      <div class="metric-box"><div class="metric-label">Air Quality Index</div><div class="metric-val">${ent.airQualityIndex?.value ?? '--'} (${ent.airQualityLevel?.value ?? ''})</div></div>
      <div class="metric-box"><div class="metric-label">Protocol</div><div class="metric-val" style="font-size:13px">${ent.lowEmissionProtocol?.value ?? 'NORMAL'}</div></div>
    `;
    controlsHtml = `
      <div class="controls">
        <button class="${stats.air_alert_mode === 'NORMAL' ? 'active' : ''}" onclick="sendActuator('air_mode', 'NORMAL')">Normal Zone</button>
        <button class="${stats.air_alert_mode === 'LOW_EMISSION_ZONE_ACTIVE' ? 'active' : ''}" onclick="sendActuator('air_mode', 'LOW_EMISSION_ZONE_ACTIVE')">Activate Low-Emission Zone</button>
      </div>
    `;
  } else if (type === 'TrafficFlowObserved') {
    metricsHtml = `
      <div class="metric-box"><div class="metric-label">Vehicle Flow</div><div class="metric-val">${ent.intensity?.value ?? '--'} veh/h</div></div>
      <div class="metric-box"><div class="metric-label">Avg Speed</div><div class="metric-val">${ent.averageVehicleSpeed?.value ?? '--'} km/h</div></div>
      <div class="metric-box"><div class="metric-label">Road Occupancy</div><div class="metric-val">${ent.occupancy?.value ?? '--'} %</div></div>
      <div class="metric-box"><div class="metric-label">Signal Mode</div><div class="metric-val" style="font-size:13px">${ent.signalControlMode?.value ?? 'AUTO'}</div></div>
    `;
    controlsHtml = `
      <div class="controls">
        <button class="${stats.traffic_override === 'AUTO' ? 'active' : ''}" onclick="sendActuator('traffic_mode', 'AUTO')">Auto Adaptive</button>
        <button class="${stats.traffic_override === 'GREEN_WAVE' ? 'active' : ''}" onclick="sendActuator('traffic_mode', 'GREEN_WAVE')">Green Wave Corridor</button>
        <button class="${stats.traffic_override === 'SPEED_LIMIT_50' ? 'active' : ''}" onclick="sendActuator('traffic_mode', 'SPEED_LIMIT_50')">Enforce 50 km/h</button>
      </div>
    `;
  } else if (type === 'Streetlight') {
    metricsHtml = `
      <div class="metric-box"><div class="metric-label">Power State</div><div class="metric-val">${ent.powerState?.value ?? '--'}</div></div>
      <div class="metric-box"><div class="metric-label">Illuminance</div><div class="metric-val">${ent.illuminanceLevel?.value ?? '--'} %</div></div>
      <div class="metric-box"><div class="metric-label">Consumption</div><div class="metric-val">${ent.powerConsumption?.value ?? '--'} kW</div></div>
      <div class="metric-box"><div class="metric-label">Technology</div><div class="metric-val" style="font-size:13px">${ent.lampTechnology?.value ?? 'LED'}</div></div>
    `;
    controlsHtml = `
      <div class="controls">
        <button class="${stats.streetlight_mode === 'ON' ? 'active' : ''}" onclick="sendActuator('streetlight', 'ON')">Full 100% ON</button>
        <button class="${stats.streetlight_mode === 'ECO' ? 'active' : ''}" onclick="sendActuator('streetlight', 'ECO')">Eco Dim 45%</button>
        <button class="${stats.streetlight_mode === 'OFF' ? 'active' : ''}" onclick="sendActuator('streetlight', 'OFF')">Switch OFF</button>
      </div>
    `;
  } else {
    metricsHtml = `
      <div class="metric-box"><div class="metric-label">Solar PV Output</div><div class="metric-val">${ent.solarGenerationKw?.value ?? '--'} kW</div></div>
      <div class="metric-box"><div class="metric-label">District Load</div><div class="metric-val">${ent.totalActivePower?.value ?? '--'} kW</div></div>
      <div class="metric-box"><div class="metric-label">Storage SoC</div><div class="metric-val">${ent.batterySoc?.value ?? '--'} %</div></div>
      <div class="metric-box"><div class="metric-label">Grid Frequency</div><div class="metric-val">${ent.gridFrequency?.value ?? '--'} Hz</div></div>
    `;
  }

  return `
    <div class="card">
      <div class="card-header">
        <div>
          <div class="card-title">${ent.name?.value || ent.id}</div>
          <div class="entity-urn">${ent.id}</div>
        </div>
        <span class="entity-type">${type}</span>
      </div>
      <div class="metrics-row">${metricsHtml}</div>
      ${controlsHtml}
    </div>
  `;
}

async function refreshState() {
  try {
    const res = await fetch('/api/state');
    const data = await res.json();
    const s = data.stats || {};
    document.getElementById('orion-dot').className = 'dot ' + (s.orion_connected ? '' : 'off');
    document.getElementById('orion-status').textContent = 'Orion v' + (s.orion_version || '...');
    document.getElementById('iota-dot').className = 'dot ' + (s.iota_connected ? '' : 'off');
    document.getElementById('iota-status').textContent = 'IoT Agent v' + (s.iota_version || '...');
    document.getElementById('updates-count').textContent = s.updates_sent || 0;
    document.getElementById('last-ts').textContent = s.last_update_ts || '--:--:--';

    const entities = data.entities || [];
    document.getElementById('entities-grid').innerHTML = entities.map(e => renderEntityCard(e, s)).join('');
    document.getElementById('raw-json').textContent = JSON.stringify(entities, null, 2);
  } catch (e) {
    console.error(e);
  }
}

refreshState();
setInterval(refreshState, 2500);
</script>
</body>
</html>
"""


class FIWAREHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def _send_json(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/api/state") or self.path.startswith("/v2/entities"):
            entities = INITIAL_ENTITIES
            try:
                st, body = http_json("GET", f"{ORION_URL}/v2/entities", timeout=2.5)
                if st == 200 and isinstance(body, list) and len(body) > 0:
                    entities = body
            except Exception:
                pass
            if self.path.startswith("/v2/entities"):
                self._send_json(200, entities)
                return
            with state_lock:
                stats_copy = dict(sim_stats)
            self._send_json(200, {"stats": stats_copy, "entities": entities})
            return

        if self.path == "/health":
            self._send_json(200, {"status": "ok"})
            return

        body = DASHBOARD_HTML.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path == "/api/actuate":
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length).decode("utf-8", errors="replace")
            try:
                req = json.loads(raw)
            except Exception:
                req = {}
            action = req.get("action")
            value = req.get("value")
            with state_lock:
                if action == "streetlight":
                    sim_stats["streetlight_mode"] = value
                    sim_stats["streetlight_dimming"] = 100 if value == "ON" else (45 if value == "ECO" else 0)
                elif action == "traffic_mode":
                    sim_stats["traffic_override"] = value
                elif action == "air_mode":
                    sim_stats["air_alert_mode"] = value
            self._send_json(200, {"status": "applied", "action": action, "value": value})
            return

        self._send_json(404, {"error": "not found"})


if __name__ == "__main__":
    t = threading.Thread(target=telemetry_loop, daemon=True)
    t.start()
    print(f"[FIWARE Smart City] Starting NGSI-v2 Control Center on 0.0.0.0:{PORT} (Orion: {ORION_URL})")
    server = HTTPServer(("0.0.0.0", PORT), FIWAREHandler)
    server.serve_forever()
