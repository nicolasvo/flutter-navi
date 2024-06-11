# osrm backend
## steps
- browse maps. granularities: continent, country, region
  + [https://download.geofabrik.de/](https://download.geofabrik.de/)
  + [https://download.geofabrik.de/europe/](https://download.geofabrik.de/europe/)
  + [https://download.geofabrik.de/europe/france/](https://download.geofabrik.de/europe/france/)
- download map
```
curl http://download.geofabrik.de/europe/france/ile-de-france-latest.osm.pbf -o ile-de-france-latest.osm.pbf
```
- pull and run image
```
docker pull ghcr.io/project-osrm/osrm-backend:v5.27.1
docker run -it --rm -v $PWD:/data ghcr.io/project-osrm/osrm-backend:v5.27.1 bash
```
- generate data for walking profile (profiles: `foot`, `bicycle`, `car`)
```
/usr/local/bin/osrm-extract -p /opt/foot.lua /data/ile-de-france-latest.osm.pbf && \
     /usr/local/bin/osrm-partition /data/ile-de-france-latest.osrm && \
     /usr/local/bin/osrm-customize /data/ile-de-france-latest.osrm
```
- run server
```
docker run -it --rm -p 6000:5000 -v $PWD:/data ghcr.io/project-osrm/osrm-backend:v5.27.1 osrm-routed --algorithm mld /data/ile-de-france-latest.osrm
```

## example
endpoints: `walking`, `driving`
```
# lyon
curl -X GET \
  'http://localhost:6000/route/v1/walking/2.3522,48.8566;4.8357,45.7640?steps=true&alternatives=false&overview=full'

# invalides 48.8594, 2.3138
curl -X GET \
  'http://localhost:6000/route/v1/walking/2.3522,48.8566;2.3138,48.8594?steps=true&alternatives=false&overview=full'
```