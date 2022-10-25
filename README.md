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

## Datenaufbereitung
Genutzte Pakete:
```R
library(tidyverse)
library(sf)
library(magrittr)
library(units)
library(lubridate)
```

Einlesen der Erhebungsdaten:
```R
spdf <- geojsonsf::geojson_sf("https://www.ogd.stadt-zuerich.ch/wfs/geoportal/Move_and_Chill?service=WFS&version=1.1.0&request=GetFeature&outputFormat=GeoJSON&typename=view_moveandchill")
```

Transformation ins übliche Koordinatensystem "CH1903+ / LV95" EPSG Code: 2056
```R
spdf = st_transform(spdf, crs = 2056)
```

Aufbereitung des Dataframes:
```R
# Zeitformat mit Lubridate umwandeln
spdf$TIME = ymd_hms(spdf$zeitpunkt, tz = "Europe/Zurich")
# Um die 30 Min. der durchschnittlich richtigen Halbstunde zuzuweisen, werden 15 Min. abgezogen. 
spdf$TIME = spdf$TIME - minutes(15)

# Zeitbestandteile für Aggregationen:
spdf$DATE = date(spdf$TIME)
spdf$YEAR = year(spdf$TIME)
spdf$MONTH = month(spdf$TIME)
spdf$DAY = day(spdf$TIME)
spdf$HOUR = hour(spdf$TIME)
spdf$MIN = minute(spdf$TIME)

# für 30-Min.-Aggregation:
spdf$halbstund = spdf$HOUR + floor((spdf$MIN)/30)/2

# X und Y ins Dataframe als Spalten
spdf <- spdf %>%
  dplyr::mutate(X = sf::st_coordinates(.)[,1],
                Y = sf::st_coordinates(.)[,2])
                
# Feiertagskalender
cal = read.csv("Feiertage.csv")
colnames(cal)[which(colnames(cal) == "Datum")] = "DATE"
cal$DATE = ymd(cal$DATE)

spdf = left_join(spdf, cal, by = "DATE")
#spdf = left_join(spdf, FVV.cal(), by = "DATE")

# Tagestypen
spdf$tagtyp = "Montag bis Donnerstag"
spdf[spdf$Wochentag == 5, "tagtyp"] = "Freitag"
spdf[spdf$Wochentag == 6, "tagtyp"] = "Samstag"
spdf[spdf$Wochentag == 7, "tagtyp"] = "Sonn- und Feiertag"
spdf[spdf$Feiertag == 1, "tagtyp"] = "Sonn- und Feiertag"
```

Räumliche Zuordnung:
```R
# Mittelpunkte beider Plätze
df.Orte = tribble(~Ort,          ~X,      ~Y,
                  "Münsterhof",  2683260, 1247170,
                  "Vulkanplatz", 2679410, 1249590)
spdf.Orte = st_as_sf(df.Orte, coords = c("X", "Y"))
spdf.Orte = st_set_crs(spdf.Orte, st_crs(spdf))

# Distanz in Metern zu beiden Platzmittelpunkten berechnen
spdf$VULK_M = drop_units(st_distance(spdf, spdf.Orte[spdf.Orte$Ort == "Vulkanplatz",]))
spdf$MUNS_M = drop_units(st_distance(spdf, spdf.Orte[spdf.Orte$Ort == "Münsterhof",]))

# Zuweisen
Dist = 500 # Zulässige Distanz vom Platzmittelpunkt für Zuweisung in Metern
spdf$Ort = "anderer Ort"
spdf[spdf$VULK_M < Dist, "Ort"] = "Vulkanplatz"
spdf[spdf$MUNS_M < Dist, "Ort"] = "Münsterhof"
```

## Ergebnisse:  

### Tagesdurchschnitte
```R
df.tage = spdf %>% st_drop_geometry %>% group_by(Ort, halbstund, DATE) %>% summarise(n = n(), sensoren = length(unique(sensor_eui)),
                                                                                     mean_sit = mean(sit),
                                                                                     med_sit = median(sit),
                                                                                     Proz = (n()/48*100)/length(unique(sensor_eui)),
                                                                                     temperature = median(temperature),
                                                                                     humidity = median(humidity))

df.tage2 = df.tage %>% group_by(Ort, DATE) %>% summarise(n = n(), 
                                                         mean_sit = mean(mean_sit),
                                                         med_sit = median(med_sit),
                                                         temperature = mean(temperature),
                                                         humidity = mean(humidity))

ggplot(df.tage2[df.tage2$Ort %in% c("Vulkanplatz", "Münsterhof"),], 
       aes(x = DATE + 0.5, y = mean_sit, fill = Ort)) + geom_col() + facet_wrap(~Ort) + theme_bw() + 
  theme(axis.title.x = element_blank(), axis.title.y = element_blank(), legend.position = "none") + 
  labs(title = "Move and Chill: Tagesdurchschnitte", 
       subtitle = "gesamte Erhebungszeit, prozentuelle Auslastung des Sitzmobiliars",
       caption = "Auswertung Tiefbauamt Stadt Zürich")
```

![alt text](https://github.com/floriafa/moveandchill/blob/main/tage.png)

Der Hauptnutzen der Sitzsensoren besteht darin, herauszufinden, wie intensiv das Sitzmobiliar genutzt wird. Die Sensoren erkennen die Nutzung mittels Beschleunigungssensoren. Die Information wird in 15 Minuten-Blocks aggregiert und als Prozentwert abgespeichert.   

Es zeigt sich, dass die Nutzung der Stühle über den Zeitraum leicht abnimmt. Im Durchschnitt waren die Stühle am Münsterhof und Vulkanplatz in etwa zu 10 Prozent genutzt. Am Münsterhof ist die Auslastung etwas höher als am Vulkanplatz.

In den ersten Tagen wurden noch unrealistisch starke Nutzungen gemessen. Das konnte darauf zurückgeführt werden, dass die Stühle im Testlauf vor der Erhebung auf anderen Oberflächen platziert wurden. Nach einer Rekalibration wurden plausible Werte gemeldet. 

Am Münsterhof wurden für Veranstaltungen die Stühle Ende September entfernt. In diesem Zeitraum gab es keine Erhebungen am Münsterhof. Nachdem der Werkhof Anfang Oktober die Zählgeräte wieder auf dem Münsterhof plaziert hatte, konnten für die letzten zwei Tage noch Nutzungsinformationen erhoben werden.


### Tagesgänge
```R
df.halbstund = spdf %>% st_drop_geometry %>% group_by(Ort, halbstund) %>% summarise(n = n(), 
                                                                     mean_sit = mean(sit),
                                                                     med_sit = median(sit)) 

ggplot(df.halbstund %>% filter(Ort != "anderer Ort"), aes(x = halbstund + 0.25, y = mean_sit, color = Ort)) + 
  scale_x_continuous(name = "",
                     breaks=c(0:24),
                     labels=c("0","","",
                              "3","","",
                              "6","","",
                              "9","","",
                              "12","","",
                              "15","","",
                              "18","","",
                              "21","","", "24"))+ geom_line(size = 1) + theme_bw() + 
  theme(axis.title.y = element_blank()) + 
  labs(title = "Move and Chill: Tagesgang", 
       subtitle = "gesamte Erhebungszeit, prozentuelle Auslastung des Sitzmobiliars, Halbstunden",
       caption = "Auswertung Tiefbauamt Stadt Zürich")
```
![alt text](https://github.com/floriafa/moveandchill/blob/main/Tagesgang.png)

   
An den Tagesgängen zeigt sich, dass beide Plätze sehr unterschiedliche Nutzungsprofile aufweisen. Der Münsterhof hat eine augeprägte Nachmittagsspitze, wo die Auslastung zwischen 14:30 und 16:30 auf über 30 Prozent ansteigt. Am Vulkanplatz ist die Auslastung am Morgen und am Abend ähnlich wie am Münsterhof. Am Nachmittag wird jedoch ein niedrigeres Auslastungsniveau von ca. 15 Prozent erreicht. 


### Wochentage
```R
# Wochentag
df.WT = spdf %>% st_drop_geometry %>% filter(Ort != "anderer Ort") %>% group_by(Ort, halbstund, tagtyp) %>% summarise(n = n(), 
                                                                                    mean_sit = mean(sit),
                                                                                    med_sit = median(sit)) 
# Wochentage in Factors umwandeln, damit Reihenfolge im Diagramm stimmt.
df.WT$tagtyp = factor(df.WT$tagtyp, levels = c("Montag bis Donnerstag", "Freitag", "Samstag", "Sonn- und Feiertag"))


ggplot(df.WT, aes(x = halbstund + 0.25, y = mean_sit, color = Ort)) + geom_line(size = 1) + 
  scale_x_continuous(name = "",
                     breaks=c(0:24),
                     labels=c("0","","",
                              "3","","",
                              "6","","",
                              "9","","",
                              "12","","",
                              "15","","",
                              "18","","",
                              "21","","", "24")) + facet_wrap(~tagtyp) + theme_bw() + 
  theme(axis.title.y = element_blank()) + 
  labs(title = "Move and Chill: Tagesgang, Wochentage", 
       subtitle = "gesamte Erhebungszeit, prozentuelle Auslastung des Sitzmobiliars, Halbstunden",
       caption = "Auswertung Tiefbauamt Stadt Zürich")
```

![alt text](https://github.com/floriafa/moveandchill/blob/main/wochentage.png)




Die einzelnen Wochentage zeigen gut, dass der Münsterhof besonders am Wochenende mehr Sitzende hat als der Vulkanplatz. Der Vulkanplatz verzeichnet gerade am Samstag sehr niedrige Auslastungswerte.

```R
pdf = spdf %>% sf::st_drop_geometry() %>% filter(DATE == "2022-09-01")

pdf$halbstund = as.factor(pdf$halbstund)

ggplot(pdf, aes(x = halbstund, y = humidity, color = Ort)) + geom_boxplot() + facet_grid(~Ort) + 
  scale_x_discrete(name = "",
                     breaks=c(levels(pdf$halbstund)),
                     labels=c("0","","1","","2","",
                              "3","","4","","5","",
                              "6","","7","","8","",
                              "9","","10","","11","",
                              "12","","13","","14","",
                              "15","","16","","17","",
                              "18","","19","","20","",
                              "21","","22","","23","")) + theme_bw() + 
  theme(axis.title.y = element_blank()) + 
  labs(title = "Move and Chill: Luftfeuchtigkeitsmessung", 
       subtitle = "1. September 2022, in Prozent, Halbstunden",
       caption = "Auswertung Tiefbauamt Stadt Zürich") + 
  theme(legend.position="none")
ggsave("Luftfeucht.png", width = 10, height = 8, units = "cm")
```

![alt text](https://github.com/floriafa/moveandchill/blob/main/Luftfeucht.png)

```R
ggplot(pdf, aes(x = halbstund, y = temperature, color = Ort)) + geom_boxplot() + facet_grid(~Ort) + 
  scale_x_discrete(name = "",
                   breaks=c(levels(pdf$halbstund)),
                   labels=c("0","","1","","2","",
                            "3","","4","","5","",
                            "6","","7","","8","",
                            "9","","10","","11","",
                            "12","","13","","14","",
                            "15","","16","","17","",
                            "18","","19","","20","",
                            "21","","22","","23","")) + theme_bw() + 
  theme(axis.title.y = element_blank()) + 
  labs(title = "Move and Chill: Lufttemperatur", 
       subtitle = "1. September 2022, in Grad Celsius, Halbstunden",
       caption = "Auswertung Tiefbauamt Stadt Zürich") + 
  theme(legend.position="none")
ggsave("Temperatur.png", width = 10, height = 8, units = "cm")
```

![alt text](https://github.com/floriafa/moveandchill/blob/main/Temperatur.png)

```R
ggplot(pdf, aes(x = halbstund, y = noise, color = Ort)) + geom_boxplot() + facet_grid(~Ort) + 
  scale_x_discrete(name = "",
                   breaks=c(levels(pdf$halbstund)),
                   labels=c("0","","1","","2","",
                            "3","","4","","5","",
                            "6","","7","","8","",
                            "9","","10","","11","",
                            "12","","13","","14","",
                            "15","","16","","17","",
                            "18","","19","","20","",
                            "21","","22","","23","")) + theme_bw() + 
  theme(axis.title.y = element_blank()) + 
  labs(title = "Move and Chill: Lärmmessung", 
       subtitle = "1. September 2022, in ??, Halbstunden",
       caption = "Auswertung Tiefbauamt Stadt Zürich") + 
  theme(legend.position="none")
ggsave("Laerm.png", width = 10, height = 8, units = "cm")
```

![alt text](https://github.com/floriafa/moveandchill/blob/main/Laerm.png)