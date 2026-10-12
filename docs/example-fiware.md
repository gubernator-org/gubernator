# Example FIWARE — Smart City & Digital Twin Platform (NGSI-v2)

This guide walks you through deploying the flagship **Open Source FIWARE Catalogue** ([fiware.org/catalogue](https://fiware.org/catalogue/)) Smart City & Digital Twin platform on **Gubernator (`gbnt`)**.

FIWARE is the European open-source standard framework for Smart Cities, Smart Industry, Smart Energy, and Digital Twins, built around the **OMA NGSI-v2 / NGSI-LD Context Management API** and standardized **Smart Data Models**.

---

## Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              GUBERNATOR CLUSTER (gbnt-net)                             │
│                                                                                        │
│  ┌──────────────────────────────┐         Ultralight 2.0 HTTP (:7896)                  │
│  │  FIWARE Smart City UI &      │ ───────────────────────────────────────┐             │
│  │  IoT Telemetry Simulator     │                                        ▼             │
│  │  (https://fiware.gbnt.local) │         Northbound Admin (:4041)  ┌────────────────┐ │
│  │  Port 8088 -> 8080           │ ────────────────────────────────► │  FIWARE IoT    │ │
│  └──────────────┬───────────────┘                                   │  Agent UL 2.0  │ │
│                 │                                                   │  (iot-agent)   │ │
│                 │ NGSI-v2 REST API (:1026)                          └───────┬────────┘ │
│                 │ (GET /v2/entities, PATCH /v2/entities/:id/attrs)          │          │
│                 ▼                                                           │ NGSI-v2  │
│  ┌──────────────────────────────┐                                           │ Updates  │
│  │  FIWARE Orion Context Broker │ ◄─────────────────────────────────────────┘          │
│  │  (orion.fiware.gbnt.local)   │                                                      │
│  │  telefonicaiot/fiware-orion  │ ───────────► ┌─────────────────────────────────────┐ │
│  └──────────────────────────────┘   :27017     │  MongoDB 6.0 (mongo-db)             │ │
│                                                │  /var/contenedores/.../mongo-data   │ │
│                                                └─────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Core FIWARE Generic Enablers Included

| Service | Official Image | Role in FIWARE Catalogue | Ports | Ingress Domain |
| :--- | :--- | :--- | :--- | :--- |
| **`orion`** | `telefonicaiot/fiware-orion:3.10.0` | **Core Context Management**: Implements the standard **OMA NGSI-v2** REST API to store, query, update, and subscribe to real-time Digital Twin context entities. | `1026:1026` | `https://orion.fiware.gbnt.local` |
| **`iot-agent`** | `fiware/iotagent-ul:1.22.0` | **IoT Agents (Interface with IoT)**: Bridges southbound IoT sensors speaking **OMA Ultralight 2.0** (`t\|22.5\|h\|48.0`) over HTTP (`:7896`) into NGSI-v2 entities in Orion (`:4041` Northbound). | `4041:4041`, `7896:7896` | `https://iot-agent.fiware.gbnt.local` |
| **`mongo-db`** | `mongo:6.0` | **Context & Device Backing Store**: Persists Orion context entities, subscriptions, service groups, and IoT device registries on `/var/contenedores` (Granaries). | `27017` (internal) | `mongo-db.fiware-smart-city.gbnt` |
| **`fiware-smart-city`** | `python:3.11-slim` | **Smart City Digital Twin Control Center**: Interactive web UI (`:8088`) and real-time telemetry simulator provisioning and streaming 6 Smart Data Models every 4 seconds. | `8088:8080` | `https://fiware.gbnt.local` |

---

## Standardized FIWARE Smart Data Models Provisioned

Upon startup, the `fiware-smart-city` service automatically registers an Ultralight 2.0 Service Group (`apikey: fiware-gbnt-iot-key`), provisions southbound IoT devices, and creates **6 standardized Smart Data Models** under `Fiware-Service: smartcity`:

| Entity ID (URN) | Smart Data Model Type | Protocol | Live Attributes |
| :--- | :--- | :--- | :--- |
| `urn:ngsi-ld:WeatherObserved:madrid-sol-01` | `WeatherObserved` | Ultralight 2.0 (`:7896`) + NGSI-v2 | `temperature` (°C), `relativeHumidity` (%), `atmosphericPressure` (hPa), `windSpeed` (m/s), `uvIndexMax`, `location` |
| `urn:ngsi-ld:AirQualityObserved:madrid-castellana-01` | `AirQualityObserved` | Ultralight 2.0 (`:7896`) + NGSI-v2 | `no2` (µg/m³), `pm10` (µg/m³), `pm25` (µg/m³), `co2` (ppm), `airQualityIndex`, `airQualityLevel` |
| `urn:ngsi-ld:TrafficFlowObserved:gran-via-east-01` | `TrafficFlowObserved` | NGSI-v2 (`:1026`) | `intensity` (veh/h), `occupancy` (%), `averageVehicleSpeed` (km/h), `congested` (Boolean) |
| `urn:ngsi-ld:Streetlight:retiro-led-01` | `Streetlight` | NGSI-v2 (`:1026`) | `powerState` (`on`/`off`/`low`), `status`, `illuminanceLevel` (0–1.0), `powerConsumption` (W), `lampTechnology` |
| `urn:ngsi-ld:ThreePhaseAcMeasurement:cibeles-solar-01` | `ThreePhaseAcMeasurement` | NGSI-v2 (`:1026`) | `activePower` (kW), `solarGenerationKw` (kW), `gridFrequency` (Hz), `batterySocPct` (%), `voltage` (V) |
| `urn:ngsi-ld:WaterQualityObserved:manzanares-01` | `WaterQualityObserved` | NGSI-v2 (`:1026`) | `ph`, `dissolvedOxygen` (mg/L), `turbidity` (NTU), `temperature` (°C), `conductivity` (µS/cm) |

---

## Step 1: Deploy the FIWARE Stack on Gubernator

You can deploy the stack in one click from the **Gubernator Web UI** or via the **CLI**.

### Option A: One-Click Deployment via Web UI (Recommended)

1. Open the Gubernator Dashboard at `http://<manager-ip>:4001`.
2. Navigate to **Legions (Stacks)** in the left sidebar.
3. Click the **POC Examples** button in the top toolbar.
4. Filter by **IoT & Industrial SCADA** and select **FIWARE Smart City & Digital Twin (Orion Context Broker + IoT Agent NGSI-v2)**.
5. Optionally choose a target Centurion node (or leave as **Auto-Schedule**) and click **Deploy Example**.

### Option B: Deployment via `gbnt` CLI

```bash
# Deploy directly from the built-in POC library:
gbnt examples deploy fiware-smart-city

# Or deploy from the standalone compose file:
gbnt stack deploy -n fiware-smart-city -c examples/example-fiware/docker-compose.yml
```

> [!NOTE]
> Gubernator automatically exports `/var/contenedores/fiware-smart-city/fiware_smart_city.py` on the Manager and synchronizes it to remote Centurion Worker nodes via SSH even if GlusterFS is not mounted.

---

## Step 2: Verify CoreDNS & Caddy Ingress Alignment

Once the 4 containers reach `running` state, Gubernator's **Aqueducts** subsystem automatically aligns **CoreDNS** and **Caddy Ingress** with the exact node IP where each service is running:

- `https://fiware.gbnt.local` ➔ Routes to `fiware-smart-city:8080` (Smart City Digital Twin Control Center)
- `https://orion.fiware.gbnt.local` ➔ Routes to `orion:1026` (FIWARE Orion Context Broker NGSI-v2 API)
- `https://iot-agent.fiware.gbnt.local` ➔ Routes to `iot-agent:4041` (FIWARE IoT Agent Northbound API)

Check the active tasks via CLI:

```bash
gbnt task ls
```

---

## Step 3: Explore the Smart City Digital Twin Control Center

Open **`https://fiware.gbnt.local`** (or `http://<node-ip>:8088`) in your browser:

1. **Live NGSI-v2 Entity Cards**: Watch real-time telemetry updates every 3 seconds from all 6 Smart City Digital Twin entities stored in Orion Context Broker.
2. **Interactive Actuation & Scenarios**:
   - **Streetlight Dimmer & Power Control**: Switch `urn:ngsi-ld:Streetlight:retiro-led-01` between **ON (100% LED)**, **ECO Mode (40% Dimmed)**, and **OFF** — this sends a live `POST /v2/entities/.../attrs` actuation command directly to FIWARE Orion.
   - **Simulate Rush Hour Traffic**: Triggers a traffic congestion spike on Gran Vía (`intensity: 2450 veh/h`, `occupancy: 91%`, `congested: true`) and an NO₂/PM2.5 alert on Paseo de la Castellana.
   - **Send Ultralight 2.0 Burst**: Sends raw `t|...|h|...` Ultralight 2.0 frames to `http://iot-agent:7896/iot/d` to observe Southbound-to-Northbound translation in real time.
3. **Built-in NGSI-v2 Raw JSON Inspector**: Switch between `GET /v2/entities (KeyValues)` and `GET /v2/entities (Full NGSI-v2)` right from the bottom console.

---

## Step 4: Query the FIWARE Orion NGSI-v2 API Directly

You can interact with the **FIWARE Orion Context Broker** directly using `curl`, Postman, or external microservices:

### 1. Check Orion Version & Health
```bash
curl -k https://orion.fiware.gbnt.local/version
```

### 2. List All Digital Twin Entities (Simplified `keyValues` Representation)
```bash
curl -k -H "Fiware-Service: smartcity" \
     -H "Fiware-ServicePath: /" \
     "https://orion.fiware.gbnt.local/v2/entities?options=keyValues"
```

### 3. Filter Entities by Type (`AirQualityObserved`) or Geo-Query
```bash
curl -k -H "Fiware-Service: smartcity" \
     -H "Fiware-ServicePath: /" \
     "https://orion.fiware.gbnt.local/v2/entities?type=AirQualityObserved&options=keyValues"
```

### 4. Send an Ultralight 2.0 Sensor Measurement to FIWARE IoT Agent
```bash
curl -i -X POST \
  "http://<node-ip>:7896/iot/d?k=fiware-gbnt-iot-key&i=weather001" \
  -H "Content-Type: text/plain" \
  -d "t|26.4|h|41.0|p|1015.2|w|3.8|uv|7"
```

### 5. Inspect Registered IoT Devices in the IoT Agent
```bash
curl -k -H "fiware-service: smartcity" \
     -H "fiware-servicepath: /" \
     "https://iot-agent.fiware.gbnt.local/iot/devices"
```

---

## Step 5: Clean Up

To stop and remove the FIWARE Smart City stack:

```bash
gbnt stack rm fiware-smart-city
```
