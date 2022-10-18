# Auswertung der Move-and-Chill-Sitzsensoren - Stadt Zürich

Das Tiefbauamt der Stadt Zürich gemeinsam mit dem EWZ und der ETH Zürich Sitzsensoren entwickelt, um in Zukunft ein Controlling-Tool für die Nutzung der mobilen Sitzelemente auf Stadtplätzen zur Verfügung zu haben.

In der Pilotphase wurden zwischen August und Oktober 2022 insgesamt 17 Sensoren am Vulkanplatz und am Münsterhof eingesetzt. 

### Weitere Informationen:
https://makezurich.ch/start/2/  
https://ethz.ch/content/dam/ethz/special-interest/itet/center-pbl-dam/documents/projects/Move_and_Chill_Challenge_Flyer.pdf

### Andere Auswertungen:
https://gis-stzh.maps.arcgis.com/apps/dashboards/6fbb7ce2f9d342e29b0d38ec154814a6  
https://github.com/DonGoginho/myPy/blob/main/plausis/plausi_messdaten/moveNDchill_geojson.ipynb  

## Datenquelle
Die von den Sitzsensoren gesammelten Daten sind öffentlich zugänglich.  
https://data.stadt-zuerich.ch/dataset/geo_move_and_chill  
https://opendata.swiss/en/dataset/move-and-chill

## Code:

```R
spdf <- geojsonsf::geojson_sf("https://www.ogd.stadt-zuerich.ch/wfs/geoportal/Move_and_Chill?service=WFS&version=1.1.0&request=GetFeature&outputFormat=GeoJSON&typename=view_moveandchill")
```

## Auswertung:  
Der Hauptnutzen der Sitzsensoren besteht darin, herauszufinden, wie intensiv das Sitzmobiliar genutzt wird. Die Sensoren erkennen die Nutzung mittels Beschleunigungssensoren. Die Information wird in 15 Minuten-Blocks aggregiert und als Prozentwert abgespeichert.   

Es zeigt sich, dass die Nutzung der Stühle über den Zeitraum leicht abnimmt. Im Durchschnitt waren die Stühle am Münsterhof und Vulkanplatz in etwa zu 10 Prozent genutzt. Am Münsterhof ist die Auslastung etwas höher als am Vulkanplatz.

In den ersten Tagen wurden noch unrealistisch starke Nutzungen gemessen. Das konnte darauf zurückgeführt werden, dass die Stühle im Testlauf vor der Erhebung auf anderen Oberflächen platziert wurden. Nach einer Rekalibration werden plausible Werte gemeldet. 

Am Münsterhof wurden für Veranstaltungen die Stühle Ende September entfernt. In diesem Zeitraum gab es keine Erhebungen am Münsterhof. Nachdem der Werkhof Anfang Oktober, die Zählgeräte wieder auf dem Münsterhof plaziert hat, konnten noch für die letzten zwei Tage der Erhebung Nutzungsinformationen ermittelt werden.
![alt text](https://github.com/floriafa/moveandchill/blob/main/tage.png)

   
An den Tagesgängen zeigt sich, dass beide Plätze sehr unterschiedliche Nutzungsprofile aufweisen. Der Münsterhof hat eine augeprägte Nachmittagsspitze, wo die Auslastung zwischen 14:30 und 16:30 auf über 30 Prozent ansteigt. Am Vulkanplatz ist die Auslastung am Morgen und am Abend ähnlich wie am Münsterhof. Am Nachmittag wird jedoch ein niedrigeres Auslastungsniveau von ca. 15 Prozent erreicht. 



![alt text](https://github.com/floriafa/moveandchill/blob/main/Tagesgang.png)

Die einzelnen Wochentage zeigen gut, dass der Münsterhof besonders am Wochenende mehr Sitzende hat als der Vulkanplatz. Der Vulkanplatz verzeichnet gerade am Samstag sehr niedrige Auslastungswerte.

![alt text](https://github.com/floriafa/moveandchill/blob/main/wochentage.png)
