##### Move and Chill-Auswertung

##### Pakete:
library(tidyverse)
library(sf)
library(magrittr)
library(units)
library(lubridate)
library(geojsonsf)

### Daten von OGD laden
spdf <- geojsonsf::geojson_sf("https://www.ogd.stadt-zuerich.ch/wfs/geoportal/Move_and_Chill?service=WFS&version=1.1.0&request=GetFeature&outputFormat=GeoJSON&typename=view_moveandchill")


### Gewünschtes Koordinatensystem "CH1903+ / LV95" EPSG Code: 2056
spdf = st_transform(spdf, crs = 2056)


### Aufbereitung Dataframe
# Zeit
# Ist "zeitpunkt" UTC, CET, CEST?
# Laut Vogt: Lokale Zeit
spdf$TIME = ymd_hms(spdf$zeitpunkt, tz = "Europe/Zurich")
# Die Daten wurden in Halbstunden aggregiert. 
# Es wird angenommen, dass "zeitpunkt" der Zeitpunkt der Übertragung ist und die
# Aggregation sich auf die 30 Min. direkt davon beziehen. 
# Um die 30 Min. der approximativ richtigen Halbstunde zuzuweisen, 
# werden somit 15 Min. abgezogen. 
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

# X und Y ins Dataframe
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

### Zuweisung Platz
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


## Plausibilisierung
# Anzahl Sensoren
length(unique(spdf$sensor_eui))

# Sensor IDs
unique(spdf$sensor_eui)

# Anzahl Datenpunkte (30 Min.) pro Platz, Tage (Datenpunkte / 48 Halbstunden):
spdf %>% st_drop_geometry() %>% group_by(Ort) %>% summarise(n = n(), Tage = n()/48)


# Anzahl Datenpunkte pro Sensor und Ort:
spdf %>% st_drop_geometry() %>% group_by(Ort, sensor_eui) %>% summarise(n = n()) %>% pivot_wider(names_from = Ort, values_from =  n)

# Datenframe-Beispiel Zählgerät "0080E115003BCF64"
spdf %>% st_drop_geometry() %>% filter(sensor_eui =="0080E115003BCF64") %>% head()
spdf %>% st_drop_geometry() %>% filter(sensor_eui =="0080E115003BCF64") %>% tail()

# Nutzung "0080E115003BCF64"
ggplot(spdf %>% st_drop_geometry() %>% filter(sensor_eui =="0080E115003BCF64"), aes(TIME, sit)) + geom_col()


# Halbtundengang
df.halbstund = spdf %>% st_drop_geometry %>% group_by(Ort, halbstund) %>% summarise(n = n(), 
                                                                     mean_sit = mean(sit),
                                                                     med_sit = median(sit)) 

ggplot(df.halbstund, aes(x = halbstund + 0.25, y = mean_sit, color = Ort)) + geom_line(size = 2)
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
ggsave("Tagesgang.png", width = 10, height = 8, units = "cm")


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
ggsave("wochentage.png", width = 10, height = 8, units = "cm")

# Monat 
df.mo = spdf %>% st_drop_geometry %>% filter(Ort != "anderer Ort") %>% group_by(Ort, halbstund, MONTH) %>% summarise(n = n(), 
                                                                                 mean_sit = mean(sit),
                                                                                 med_sit = median(sit)) 

ggplot(df.mo, aes(x = halbstund + 0.25, y = mean_sit, color = Ort)) + geom_line(size = 1) + 
  scale_x_continuous(name = "",
                     breaks=c(0:24),
                     labels=c("0","","",
                              "3","","",
                              "6","","",
                              "9","","",
                              "12","","",
                              "15","","",
                              "18","","",
                              "21","","", "24")) + facet_wrap(~MONTH) + theme_bw() + 
  theme(axis.title.y = element_blank()) + 
  labs(title = "Move and Chill: Tagesgang, Monate", 
       subtitle = "gesamte Erhebungszeit, prozentuelle Auslastung des Sitzmobiliars, Halbstunden",
       caption = "Auswertung Tiefbauamt Stadt Zürich")
ggsave("monate.png", width = 10, height = 8, units = "cm")


# Alle Tage

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
ggsave("tage.png", width = 10, height = 8, units = "cm")

# sit + Temperatur + Luftfeuchtigkeit

ggplot(df.tage2 %>% filter(Ort != "anderer Ort"), 
       aes(x = DATE + 0.5, y = mean_sit, fill = Ort)) + geom_col() + 
  #geom_text(data = df.tage2 %>% filter(Ort != "anderer Ort"), aes(x=DATE + 0.5, y=0, label=round(n/48)), size=2) +
  geom_line(data = df.tage2 %>% filter(Ort != "anderer Ort"), aes(x=DATE + 0.5, y=temperature), color = "red") + 
  geom_line(data = df.tage2 %>% filter(Ort != "anderer Ort"), aes(x=DATE + 0.5, y=humidity), color = "blue") + facet_wrap(~Ort)+ theme_bw() + 
  theme(axis.title.x = element_blank(), axis.title.y = element_blank(), legend.position = "none") + 
  labs(title = "Move and Chill: Tagesdurchschnitte", 
       subtitle = "%-Auslastung des Sitzmobiliars, Temperatur rot, Luftfeuchtigkeit blau",
       caption = "Auswertung Tiefbauamt Stadt Zürich")
ggsave("tage_wetter.png", width = 10, height = 8, units = "cm")


## Lärmentwicklung:
## Median, Abweichung
## 
## Temperatur + Luftfeuchtigkeit
## 

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
ggsave("Luftfeucht.png", width = 20, height = 16, units = "cm")

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
ggsave("Temperatur.png", width = 20, height = 16, units = "cm")

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
ggsave("Laerm.png", width = 20, height = 16, units = "cm")
