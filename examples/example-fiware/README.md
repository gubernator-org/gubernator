# 🏙️ FIWARE Smart City & Digital Twin Platform (NGSI-v2)

This example deploys the most representative **Open Source FIWARE Catalogue** ([fiware.org/catalogue](https://fiware.org/catalogue/)) architecture on **Gubernator (`gbnt`)**:

1. **FIWARE Orion Context Broker** (`telefonicaiot/fiware-orion:3.10.0`) — The core Generic Enabler of the FIWARE platform, implementing the **OMA NGSI-v2** REST API on port `1026` to manage real-time context information and Digital Twin entities.
2. **FIWARE IoT Agent for Ultralight 2.0** (`fiware/iotagent-ul:1.22.0`) — Southbound IoT gateway bridging constrained IoT devices sending Ultralight 2.0 payloads (`t|23.4|h|48.2`) on port `7896` into NGSI-v2 entities in Orion, with Northbound provisioning on port `4041`.
3. **MongoDB 6.0** (`mongo:6.0`) — Persistent NoSQL backing store holding context entities, subscriptions, and IoT device registries in `/var/contenedores/fiware-smart-city/mongo-data`.
4. **FIWARE Smart City Control Center & IoT Simulator** (`fiware-smart-city`) — Zero-dependency Python web dashboard (`https://fiware.gbnt.local` / port `8088`) and real-time telemetry simulator provisioning and updating 6 **FIWARE Smart Data Models** entities every 4 seconds.

---

## 🌐 Ingress & Service Discovery (Caddy + CoreDNS)

When deployed on Gubernator, CoreDNS and Caddy automatically align the `ingress.host` labels to the node IP where each service runs:

| Service | Ingress Domain (HTTPS via Caddy) | Direct Host Port | Internal `gbnt-net` DNS |
| :--- | :--- | :--- | :--- |
| **Smart City Control Center UI** | `https://fiware.gbnt.local` | `:8088` | `fiware-smart-city:8080` |
| **FIWARE Orion Context Broker** | `https://orion.fiware.gbnt.local` | `:1026` | `orion:1026` |
| **FIWARE IoT Agent (Northbound)** | `https://iot-agent.fiware.gbnt.local` | `:4041` | `iot-agent:4041` |
| **FIWARE IoT Agent (Ultralight HTTP)** | — | `:7896` | `iot-agent:7896` |

---

## 📊 Provisioned FIWARE Smart Data Models

| Entity ID (URN) | Entity Type | Protocol | Live Attributes |
| :--- | :--- | :--- | :--- |
| `urn:ngsi-ld:WeatherObserved:madrid-sol-01` | `WeatherObserved` | Ultralight 2.0 (`:7896`) + NGSI-v2 | `temperature`, `relativeHumidity`, `atmosphericPressure`, `windSpeed`, `uvIndexMax` |
| `urn:ngsi-ld:AirQualityObserved:madrid-castellana-01` | `AirQualityObserved` | Ultralight 2.0 (`:7896`) + NGSI-v2 | `no2`, `pm10`, `pm25`, `co2`, `airQualityIndex`, `airQualityLevel` |
| `urn:ngsi-ld:TrafficFlowObserved:gran-via-east-01` | `TrafficFlowObserved` | NGSI-v2 (`:1026`) | `intensity`, `occupancy`, `averageVehicleSpeed`, `congested` |
| `urn:ngsi-ld:Streetlight:retiro-led-01` | `Streetlight` | NGSI-v2 (`:1026`) | `powerState`, `status`, `illuminanceLevel`, `powerConsumption` |
| `urn:ngsi-ld:ThreePhaseAcMeasurement:cibeles-solar-01` | `ThreePhaseAcMeasurement` | NGSI-v2 (`:1026`) | `activePower`, `solarGenerationKw`, `gridFrequency`, `batterySocPct` |
| `urn:ngsi-ld:WaterQualityObserved:manzanares-01` | `WaterQualityObserved` | NGSI-v2 (`:1026`) | `ph`, `dissolvedOxygen`, `turbidity`, `temperature`, `conductivity` |

---

## 🚀 Quick Deployment

### Option A: One-Click from Gubernator Web UI
1. Open the Gubernator Dashboard (`http://<manager-ip>:4001`).
2. Go to **Legions (Stacks)** ➔ **POC Examples**.
3. Select **FIWARE Smart City & Digital Twin (Orion Context Broker + IoT Agent NGSI-v2)** and click **Deploy**.

### Option B: Deploy via Gubernator CLI (`gbnt`)
```bash
# Deploy directly from the built-in POC catalog:
gbnt examples deploy fiware-smart-city

# Or deploy from this compose file:
gbnt stack deploy -n fiware-smart-city -c examples/example-fiware/docker-compose.yml
```

---

## 🔍 Testing the NGSI-v2 API with `curl`

```bash
# 1. Check Orion Context Broker version & uptime
curl -k https://orion.fiware.gbnt.local/version

# 2. Query all Smart City Digital Twin entities (Simplified KeyValues)
curl -k -H "Fiware-Service: smartcity" \
     -H "Fiware-ServicePath: /" \
     "https://orion.fiware.gbnt.local/v2/entities?options=keyValues"

# 3. Query only Air Quality sensors
curl -k -H "Fiware-Service: smartcity" \
     "https://orion.fiware.gbnt.local/v2/entities?type=AirQualityObserved&options=keyValues"

# 4. List registered IoT devices in FIWARE IoT Agent
curl -k -H "fiware-service: smartcity" \
     -H "fiware-servicepath: /" \
     "https://iot-agent.fiware.gbnt.local/iot/devices"
```
