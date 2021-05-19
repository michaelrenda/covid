library(here)
library(tidyverse)
library(tidyr)
library(dplyr)
library(readr)
library(ggplot2)
library(odbc)
library(RMySQL)
library(RCurl)
library(maps)
library(grid)
library(mapproj)
library(scales)

##  function to set a map theme
theme_map <- function(base_size=9, base_family="") {
  require(grid)
  theme_bw(base_size = base_size, base_family = base_family) %+replace%
    theme(axis.line=element_blank(),
          axis.text=element_blank(),
          axis.ticks=element_blank(),
          axis.title.x = element_blank(),
          axis.title.y = element_blank(),
          panel.background = element_blank(),
          panel.border = element_blank(),
          panel.grid = element_blank(),
          panel.spacing = unit(0, "lines"),
          plot.background = element_blank(),
          legend.justification = c(0,0),
          legend.position = c(0,0)
    )
}

##  reformat dates from the source data
prepDates <- function(inDates) {
  outDates <- as.vector(c(rep(date(),length(inDates))));
  for (n in 1:length(inDates)) {
    splitDay <- str_split_fixed(inDates[n], "/", 3);
    nDay = as.numeric(splitDay[1,2]);
    nMonth = as.numeric(splitDay[1,1]);
    outDates[n] <- paste0("20", splitDay[1,3], "-", sprintf("%02d", nMonth), "-", sprintf("%02d",nDay));
  }
  outDates;
}

##  massage source data, summarize and merge confirmed cases & deaths
prepDF <- function(confirmedDF, deathsDF) {
### process confirmed cases
confirmedDF <- select(confirmedDF, obs_date, cum_confirmed)        # eliminate unnessary columns
subConfirmed <- aggregate(cum_confirmed ~ obs_date,data=confirmedDF, FUN = sum, na.rm = TRUE, na.action = NULL)   # sum by date
### process deaths
deathsDF <- select(deathsDF, obs_date, cum_deaths)
subDeaths <- aggregate(cum_deaths ~ obs_date,data=deathsDF, FUN = sum, na.rm = TRUE, na.action = NULL)
#  merge confirmed & deaths by date
newDF <- merge(x = subConfirmed, y = subDeaths, by = "obs_date", all.x = TRUE)
formattedDates <- prepDates(newDF$obs_date);   # reformat the dates
newDF <- cbind(formattedDates,newDF);
newDF <- newDF[order(newDF$formattedDates),];
new_deaths <- c(newDF$cum_deaths[1],diff(newDF$cum_deaths))   #  compute the new cases by diff on cumulative values
new_cases <- c(newDF$cum_confirmed[1],diff(newDF$cum_confirmed))
newDF <- cbind(newDF, new_cases, new_deaths);    ## add new cases / new deaths into the data frame
newDF <- select(newDF, formattedDates, cum_confirmed, new_cases, cum_deaths, new_deaths);
newDF <- rename(newDF, obs_date = formattedDates)
newDF;
}

##  create the plots and save to files
plotUnit <- function(sumUnit, unitName, unitTitle1, unitTitle2, unitDir) {
  weeks_string = paste(c(as.integer(difftime(Sys.Date(),strptime("01.01.2020", format = "%d.%m.%Y"), units="weeks") / 12), "weeks"), collapse = " ")
  options(scipen = 8)
  cumNumber <- format(sumUnit$cum_confirmed[length(sumUnit$cum_confirmed)], big.mark = ",");
  p <- ggplot(data=sumUnit, mapping = aes(x=as.Date(obs_date), y=new_cases)) +
  geom_bar(stat = "identity", color = "blue", fill = "blue") +
  theme(plot.caption = element_text(size = 8, color = "Blue")) +
  scale_x_date(date_breaks = weeks_string, date_labels =  "%m/%d/%y") +
  labs(x = "", y = "", title=unitTitle1, subtitle="with smoothed trend line", caption=paste0("Cumulative: ",cumNumber, " cases\nUpdated: ",date(),"\nSource: Center for Systems Science and Engineering at Johns Hopkins University")) + geom_smooth(alpha=.5, color="cyan4", method="gam")
  ggsave(paste0(unitDir, unitName,"Confirmed.png"),plot = p, width=8, height=5);
  cumDeaths <- format(sumUnit$cum_deaths[length(sumUnit$cum_deaths)], big.mark = ",");
  p <- ggplot(data=sumUnit, mapping = aes(x=as.Date(obs_date), y=new_deaths)) +
  geom_bar(stat = "identity", color = "blue", fill = "blue") +
  theme(plot.caption = element_text(size = 8, color = "Blue")) +
  scale_x_date(date_breaks = weeks_string, date_labels =  "%m/%d/%y") + scale_y_continuous(label = comma) +
  labs(x = "", y = "", title=unitTitle2, subtitle="with smoothed trend line", caption=paste0("Cumulative: ",cumDeaths, " deaths\nUpdated: ",date(),"\nSource: Center for Systems Science and Engineering at Johns Hopkins University")) + geom_smooth(alpha=.5, color="cyan4", method="gam")
  ggsave(paste0(unitDir,unitName,"Deaths.png"),plot = p, width=8, height=5);
}

## read config entries
fileName <- "/config/covid-config.txt"
conn <- file(fileName,open="r")
linn <-readLines(conn)
user_name = linn[1]
user_pw = linn[2]
db_name = linn[3]
db_host = linn[4]
close(conn)

## set up directories
startDir <- "/data/"

#  download confirmed
# url <- "https://github.com/CSSEGISandData/COVID-19/raw/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_US.csv"
# confirmedUS <- read_csv(url)
# confirmedUSTidy <- confirmedUS %>% gather("obs_date", "cum_confirmed", - c("UID", "iso2", "iso3", "code3", "FIPS", "Admin2", "Province_State", "Country_Region", "Lat", "Long_", "Combined_Key"))

#  download deaths
# url <- "https://github.com/CSSEGISandData/COVID-19/raw/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_deaths_US.csv"
# deathsUS <- read_csv(url)
# deathsUSTidy <- deathsUS %>% gather("obs_date", "cum_deaths", - c("UID", "iso2", "iso3", "code3", "FIPS", "Admin2", "Province_State", "Country_Region", "Lat", "Long_", "Combined_Key","Population"))

## process graphs for US Totals
# sumUS <- prepDF(confirmedUSTidy, deathsUSTidy)
# plotUnit(sumUS, "US", "US - New Cases Per Day", "US - Deaths per Day", startDir);



## loop through states
# usFactor <- factor(confirmedUSTidy$Province_State);
# for (stateUS in levels(usFactor)) {
#   # extract the state
#   confirmedState <- filter(confirmedUSTidy, Province_State == stateUS)
#   deathsState <- filter(deathsUSTidy, Province_State == stateUS)

#   sumState <- prepDF(confirmedState, deathsState)
#   plotUnit(sumState, stateUS, paste0(stateUS," - New Cases Per Day"), paste0(stateUS, " - Deaths per Day"), startDir );

#   countyDir <- paste0("/figures/",stateUS);
#   if (dir.exists(paste0(getwd(),countyDir)) == FALSE) {
#     dir.create(paste0(getwd(),countyDir))
#   }
#   ## loop through counties in each state
#   countyState = factor(confirmedState$Admin2)
#   for (county in levels(countyState)) {
#     confirmedCounty <- filter(confirmedState, Admin2 == county)
#     deathsCounty <- filter(deathsState, Admin2 == county)
#     sumCounty <- prepDF(confirmedCounty, deathsCounty)
#     plotUnit(sumCounty, county, paste0(county," - New Cases Per Day"), paste0(county, " - Deaths per Day"), paste0(startDir,stateUS,"/" ) );
#   }
# }

## update MySQL db with US daily reports
con <- dbConnect(MySQL(), user=user_name, password=user_pw, dbname=db_name, host=db_host)

query_date <- dbGetQuery(con, "Select max(add_date) dbdate FROM CSSE_COVID_19_DATA_DAILY");
next_date = as.Date(query_date$dbdate) + 1;
while (next_date <= Sys.Date()) {
  print(paste(next_date, "\n", sep=""));
  file_date <- format(next_date,"%m-%d-%Y");
  rev_date <- format(next_date, "%Y-%m-%d");
  
  url <- paste("https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_daily_reports_us/",file_date,".csv", sep="")
  if (url.exists(url)) {
    confirmedUS <- read_csv(url)
    add_date <- c(rep(rev_date,nrow(confirmedUS)))
    cUS <- cbind(confirmedUS,add_date)
    cUS <- filter(cUS, Country_Region == "US")
    cUS[4:15][is.na(cUS[4:15])] <- 0;
    cUS[17:18][is.na(cUS[17:18])] <- 0;
    cUS[3][is.na(cUS[3])] <- add_date[1];
    for (i in 1:nrow(cUS)) {
      sql_statement = paste("INSERT INTO CSSE_COVID_19_DATA_DAILY VALUES('",cUS$Province_State[i],"' ,'",cUS$Country_Region[i],"', STR_TO_DATE('",cUS$Last_Update[i],
                            "','%Y-%m-%d %H:%i:%s'), ",cUS$Lat[i],", ",cUS$Long_[i],", ",cUS$Confirmed[i],", ",cUS$Deaths[i],", ",cUS$Recovered[i],", ",cUS$Active[i],", ",
                            cUS$FIPS[i],", ",cUS$Incident_Rate[i],", ",cUS$Total_Test_Results[i],", ",cUS$People_Hospitalized [i],", ",cUS$Case_Fatality_Ratio[i],", ",
                            cUS$UID[i],", '",cUS$ISO3[i],"', ",cUS$Testing_Rate[i],", ",cUS$Hospitalization_Rate[i],", STR_TO_DATE('",cUS$add_date[i],"','%Y-%m-%d'))",sep="") ;
      dbGetQuery(con, sql_statement);
    }
  }
  next_date <- next_date + 1;
}

## update the MySQL db with world daily reports
query_date <- dbGetQuery(con, "Select max(add_date) dbdate FROM CSSE_COVID_19_WORLD_DATA");
next_date = as.Date(query_date$dbdate) + 1;
while (next_date <= Sys.Date()) {
  print(paste(next_date, "\n", sep=""));
  file_date <- format(next_date,"%m-%d-%Y");
  rev_date <- format(next_date, "%Y-%m-%d");
  
  url <- paste("https://github.com/CSSEGISandData/COVID-19/raw/master/csse_covid_19_data/csse_covid_19_daily_reports/",file_date,".csv", sep="")
  if (url.exists(url)) {
    confirmedWorld <- read_csv(url)
    confirmedWorld[4:6][is.na(confirmedWorld[4:6])] <- 0;
    confirmedWorld[3][is.na(confirmedWorld[3])] <- rev_date;
    cWorld <- aggregate(cbind(confirmedWorld$Confirmed , confirmedWorld$Deaths, confirmedWorld$Recovered), by=list(confirmedWorld$`Country_Region`),  FUN = sum)
    cWorld <- rename(cWorld, country=Group.1, confirmed=V1, deaths=V2, recovered=V3)
    add_date <- c(rep(rev_date,nrow(cWorld)))
    last_update <- c(rep(file_date,nrow(cWorld)))
    cWorld <- cbind(cWorld,add_date)
    cWorld <- cbind(cWorld,last_update)
      for (i in 1:nrow(cWorld)) {
        if (is.na(cWorld$recovered[i])) {
          cWorld$recovered[i] = 0;
        }
        country <- cWorld$country[i];
        country <- gsub("'", "''", country)
        sql_statement = paste("INSERT INTO CSSE_COVID_19_WORLD_DATA VALUES('" , country , "', STR_TO_DATE('", cWorld$last_update[i] , "','%m-%d-%Y'), ", cWorld$confirmed[i], ", " , cWorld$deaths[i] , ", " , cWorld$recovered[i] , ", STR_TO_DATE('" , cWorld$add_date[i] , "','%Y-%m-%d'))", sep="")
        dbGetQuery(con, sql_statement);
      }
  }
  next_date <- next_date + 1;
}

##  plot out the incidence rate
i_rate <- dbGetQuery(con, "select a.abbr, a.name, a.fips, b.incident_rate from US_STATES a, CSSE_COVID_19_DATA_DAILY b where a.fips = b.fips and b.add_date = (select max(c.add_date) from CSSE_COVID_19_DATA_DAILY c) order by b.incident_rate");
i_rate$region <- tolower(i_rate$name);
m_rate <- dbGetQuery(con, "select a.abbr, a.name, a.fips, b.mortality_rate from US_STATES a, CSSE_COVID_19_DATA_DAILY b where a.fips = b.fips and b.add_date = (select max(c.add_date) from CSSE_COVID_19_DATA_DAILY c) order by b.mortality_rate");
m_rate$region <- tolower(i_rate$name);
us_states <- map_data("state");
us_states_irate <- merge(x = us_states, y = i_rate, by = "region", all.x = TRUE)
us_states_mrate <- merge(x = us_states, y = m_rate, by = "region", all.x = TRUE)
m0 <- ggplot(data = us_states_irate, 
             mapping = aes(x = long, y = lat, group = group, fill = incident_rate));
m1 <-  m0 + geom_polygon(color = "gray90", size = .1) + 
  coord_map(projection = "albers", lat0 = 39, lat1 = 45)
m2 <- m1 + scale_fill_gradient2(low = "blue", high="red") + labs(title = "US Covid-19 Incidence Rate", subtitle="cases per 100k population")  + theme_map() +labs(fill = "Case Rate");
ggsave(paste0(startDir,"/USIncidenceRate.png"),plot = m2, width=8, height=5)

m0 <- ggplot(data = us_states_mrate, 
             mapping = aes(x = long, y = lat, group = group, fill = mortality_rate));
m1 <-  m0 + geom_polygon(color = "gray90", size = .1) + 
  coord_map(projection = "albers", lat0 = 39, lat1 = 45)
m2 <- m1 + scale_fill_gradient2(low = "blue", high="red") + labs(title = "US Covid-19 Mortality Rate", subtitle="deaths per 100 cases")  + theme_map() +labs(fill = "Mortality Rate");
ggsave(paste0(startDir,"/USMortalityRate.png"),plot = m2, width=8, height=5)
dbDisconnect(con);
