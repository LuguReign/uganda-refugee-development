##########################################
# Refugee Exposure, Elections, Development
# Parish Data Clean
# Dec 2, 2020
##########################################

# Using newly cleaned electoral + controls + 2020 schools, HCs, roads data from Shuning
# Dissolved 2002 parish shapefiles 
# New 2020 refugee sites shapefils
sf::sf_use_s2(FALSE)

library(tidyverse)
library(rgdal)
library(raster)
library(sf)
library(doMC)
library(haven)
library(estimatr)
library(geosphere)
library(readxl)

entry_to_label <- function(x){
    require(labelled)
    tab <- data.frame(entry = val_labels(x)) %>%
        mutate(label = rownames(.)) 
    match_to_tab <- match(x, tab$entry)
    lab_vec <- tab$label[match_to_tab]
    return(factor(lab_vec, level = tab$label))
}

log_p1 <- function(x){return(log(x+1))}

## ---------------
## Load shapefiles
## ---------------
## Main refugee camp shapefile
refsites <- readOGR(path.expand("ugakaimug"), "settlement_boundaries")

## Mungula site which was newly setup
refsites_mungula <- readOGR(path.expand("UGA_mungula_ii"), "UGA_mungula_ii")
refsites_mungula <- spTransform(refsites_mungula, crs(refsites))
refsites_mungula@data = refsites_mungula@data %>% 
  mutate(Name_setlm = "Mungula II", District = "Adjumani", Sqkm = 10.279261) %>%
  dplyr::select(District, Name_setlm, Sqkm)

## Kitgum and Okollo sites
refsites_kitgum_okollo <- readOGR(path.expand("Kitgum and Okollo"), "Boundaries_Kitgum_Okollo")
refsites_kitgum_okollo <- spTransform(refsites_kitgum_okollo, crs(refsites))

## Dissolved parish shapefiles
parish <- readOGR(path.expand("Uganda_Parish_Boundaries_2002_dissolved_final"), "uganda_2002_dissolve4")

## Clean up refsites names
refsites@data$Name_setlm <- as.character(refsites@data$Name_setlm)
refsites@data$Name_setlm[4] <- "Oliji I"
refsites@data$Name_setlm[5] <- "Oliji II"
refsites@data$Name_setlm[17] <- "Maaji 1A"
refsites@data$Name_setlm[18] <- "Maaji 1B"
refsites@data$Name_setlm[30] <- "Palorinya I"
refsites@data$Name_setlm[31] <- "Palorinya II"
refsites@data$Name_setlm[32] <- "Palorinya III"
refsites@data$Name_setlm[33] <- "Palorinya IV"
refsites@data$Name_setlm[34] <- "Palorinya V"
refsites@data$Name_setlm[35] <- "Palorinya VI"
refsites@data$Name_setlm[36] <- "Palorinya VII"
refsites@data$Name_setlm[37] <- "Palorinya VIII"
refsites@data$Name_setlm[38] <- "Palorinya IX"
refsites@data$Name_setlm[39] <- "Palorinya X"

length(unique(refsites@data$Name_setlm))

## -------------------------------
## Get distance to nearest refsite
## -------------------------------
refsites_sf <- st_as_sf(refsites)
refsites_ko_sf <- st_as_sf(refsites_kitgum_okollo)
refsites_mungula_sf <- st_as_sf(refsites_mungula)
parish_sf <- st_as_sf(parish) %>% st_transform(st_crs(refsites_ko_sf))

# ## WARNING:
# ##     TAKES HOURS TO RUN
# registerDoMC(detectCores()-1)
# refsites_dist <- foreach(i = 1:nrow(parish_sf), .combine = "rbind") %dopar% {
#     out <- st_distance(parish_sf[i,], refsites_sf)
#     if(i %% 100 == 0){
#         print(paste0("Done with ", i, " parishes at ", Sys.time(), "."))
#     }
#     return(out/1000)
# }
# write_csv(as.data.frame(refsites_dist), path = "parish_distance_to_refsite.csv")

refsites_dist <- read_csv("parish_distance_to_refsite.csv")

# ## Add in kitgum and okollo
# registerDoMC(detectCores()-1)
# refsites_ko_dist <- foreach(i = 1:nrow(parish_sf), .combine = "rbind") %dopar% {
#     out <- st_distance(parish_sf[i,], refsites_ko_sf)
#     if(i %% 100 == 0){
#         print(paste0("Done with ", i, " parishes at ", Sys.time(), "."))
#     }
#     return(out/1000)
# }
# write_csv(as.data.frame(refsites_ko_dist), path = "parish_distance_to_refsite_kitgum_okollo.csv")

refsites_ko_dist <- read_csv("parish_distance_to_refsite_kitgum_okollo.csv")

# ## Add in Mungula II
# registerDoMC(detectCores()-1)
# refsites_mungula_dist <- foreach(i = 1:nrow(parish_sf), .combine = "rbind") %dopar% {
#     out <- st_distance(parish_sf[i,], refsites_mungula_sf)
#     if(i %% 100 == 0){
#         print(paste0("Done with ", i, " parishes at ", Sys.time(), "."))
#     }
#     return(out/1000)
# }
# write_csv(as.data.frame(refsites_mungula_dist), path = "parish_distance_to_refsite_mungula.csv")

refsites_mungula_dist <- read_csv("parish_distance_to_refsite_mungula.csv")

## Put together
refsites_dist <- bind_cols(refsites_dist, refsites_ko_dist, refsites_mungula_dist)
colnames(refsites_dist) <- paste(
  c(refsites@data$Name_setlm, as.character(refsites_kitgum_okollo@data$Name), refsites_mungula@data$Name_setlm), 
"Distance")

## ----------------------
## Get distance to border
## ----------------------
uganda_boundary <- readOGR(path.expand("Uganda_countryboundaries_adm0"), 
                           "uga_admbnda_adm0_UBOS_v2")

# ## WARNING:
# ##     TAKES HOURS TO RUN
# ## Calculate distance
# registerDoMC(detectCores()-1)
# border_dist <- foreach(i = 1:nrow(parish), .combine = "rbind") %dopar% {
#     parish_sp <- SpatialPoints(parish[i,], proj4string = crs(parish))
#     out <- dist2Line(parish_sp, uganda_boundary)
#     if(i %% 100 == 0){
#         print(paste0("Done with ", i, " parishes at ", Sys.time(), "."))
#     }
#     return(out[,1]/1000)
# }
# write_csv(as.data.frame(border_dist), path = "parish_distance_to_border.csv")

border_dist <- read_csv("parish_distance_to_border.csv")
colnames(border_dist) <- "borderdist"

## --------------------
## Get distance to road
## --------------------
uganda_road <- readOGR(path.expand("Uganda_roads_feb2009"), "Uganda_Roads_Feb2009")
uganda_road <- spTransform(uganda_road, crs(parish))
uganda_road_sf <- st_as_sf(uganda_road)

# ## WARNING:
# ##     TAKES HOURS TO RUN
# ## Calculate distance
# registerDoMC(detectCores()-1)
# road_dist <- foreach(i = 1:nrow(parish_sf), .combine = "rbind") %dopar% {
#     out <- st_distance(parish_sf[i,], uganda_road_sf)
#     if(i %% 100 == 0){
#         print(paste0("Done with ", i, " parishes at ", Sys.time(), "."))
#     }
#     return(min(as.numeric(out))/1000)
# }
# write_csv(as.data.frame(road_dist), path = "parish_distance_to_road.csv")

road_dist <- read_csv("parish_distance_to_road.csv")
colnames(road_dist) <- "roaddist"

## -----------------------
## Get distance to capital
## -----------------------
kampala_coord <- st_point(x = c(32.595242, 0.310841)) %>%
  st_sfc(crs = st_crs(parish_sf))

registerDoMC(detectCores()-1)
cap_dist <- foreach(i = 1:nrow(parish_sf), .combine = "rbind") %dopar% {
    out <- st_distance(parish_sf[i,], kampala_coord)
    if(i %% 100 == 0){
        print(paste0("Done with ", i, " parishes at ", Sys.time(), "."))
    }
    return(out[1,1]/1000)
}

cap_dist <- as.data.frame(cap_dist)
colnames(cap_dist) <- "capitoldist"

## -------------------------
## Merge onto electoral data
## -------------------------
## D = District
## C = County
## S = Sub-county
## P = Parish
parish_data <- parish@data 

parish_data <- bind_cols(parish_data, refsites_dist) %>%
  bind_cols(border_dist) %>%
  bind_cols(road_dist) %>%
  bind_cols(cap_dist) %>%
  mutate(P_02_ID = as.character(P_02_ID))

## Load political data and merge
pol_data <- read_csv("final_election_control_Dev_Econ_Paper_v6.1.csv") %>%
  mutate(P_02_ID = as.character(P_02_ID))
pol_data %>% 
  group_by(P_02_ID, year) %>% count() %>%
  arrange(desc(n))

## Check correspondence between parish IDs
stopifnot(all(pol_data$P_02_ID %in% parish_data$P_02_ID))
stopifnot(all(parish_data$P_02_ID %in% pol_data$P_02_ID))
stopifnot(nrow(parish_data) == length(unique(parish_data$P_02_ID)))
stopifnot((nrow(pol_data)/5) == length(unique(pol_data$P_02_ID)))

## ----------------------------------------
## Get district assignment for each refsite
## ----------------------------------------
refsite_all <- st_as_sf(refsites) %>%
  bind_rows(st_as_sf(refsites_kitgum_okollo)) %>%
  bind_rows(st_as_sf(refsites_mungula)) %>%
  mutate(Name_setlm = coalesce(Name_setlm, Name)) %>%
  st_transform(st_crs(parish))
parish@data <- parish@data %>%
  left_join(
    pol_data %>%
      dplyr::select(P_02_ID, D_02_ID) %>%
      distinct()
  )

refsite_onto_parish <- st_intersects(
  st_as_sf(refsite_all),
  st_as_sf(parish)
)

## Unpack adjacency list
refsite_onto_parish <- map_dfr(refsite_onto_parish, ~tibble(parish_id = .x), .id = "refsite_id")
refsite_onto_parish$D_02_ID <- parish@data$D_02_ID[refsite_onto_parish$parish_id]
refsite_onto_parish$Name_setlm <- refsite_all$Name_setlm[as.numeric(refsite_onto_parish$refsite_id)]

refsite_district <- refsite_onto_parish %>%
  dplyr::select(Name_setlm, D_02_ID) %>%
  distinct() %>%
  group_by(Name_setlm) %>%
  mutate(obs_num = row_number()) %>%
  pivot_wider(names_from = obs_num, values_from = D_02_ID,
              names_prefix = "D_02_ID_") %>%
  mutate(D_02_ID_2 = coalesce(D_02_ID_2, -99),
         D_02_ID_3 = coalesce(D_02_ID_3, -99))

## ---------------------
## Match data on P_02_ID
## ---------------------
## Merge to get distance variables
df_parish_key <- pol_data %>% 
  dplyr::select(P_02_ID, year) %>%
  inner_join(
    parish_data %>% dplyr::select(P_02_ID, ends_with("Distance"), ends_with("dist")),
    by = c("P_02_ID")
  )
stopifnot(nrow(df_parish_key) == nrow(pol_data))

df_parish_key <- df_parish_key %>%
  mutate(
    min_distance = pmap_dbl(
      .l = dplyr::select(., ends_with(" Distance")),
      .f = function(...) min(...)
    )
  )

## Combine back to the pol data, left-join so that non-matches are NAs
pol_data_merged <- inner_join(pol_data, df_parish_key, by = c("P_02_ID", "year"))
stopifnot(nrow(pol_data_merged) == nrow(pol_data))
  
pol_data_merged %>% 
  group_by(P_02_ID, year) %>%
  count() %>%
  arrange(desc(n))

sum(is.na(pol_data_merged$`Palorinya X Distance`))

## --------------------------------
## Merge in the populations by year
## --------------------------------
refsites_pop <- read_csv("uga_refsites_population_final_analysis.csv")
refsites_pop <- refsites_pop %>%
  dplyr::select(Name_setlm, Year, `Refugee Population`) 

## Add in population data for Mungula II (2020)
refsites_pop[(nrow(refsites_pop)+1),] <- list("Mungula II", 2020, 1593)
refsites_pop[(nrow(refsites_pop)+1),] <- list("Mungula II", 2015, 0)
refsites_pop[(nrow(refsites_pop)+1),] <- list("Mungula II", 2010, 0)
refsites_pop[(nrow(refsites_pop)+1),] <- list("Mungula II", 2005, 0)
refsites_pop[(nrow(refsites_pop)+1),] <- list("Mungula II", 2000, 0)
refsites_pop$Year[refsites_pop$Year==2020] <- 2019

## Correct population in Adjumani
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Nyumanzi")] <- 40551
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Pagirinya")] <- 36768
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Ayilo I")] <- 25893
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Maaji II")] <- 17365
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Maaji III")] <- 15366
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Ayilo II")] <- 14506
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Boroli 1")] <- 10049
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Agojo")] <- 7054
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Baratuku")] <- 6921
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Mirieyi")] <- 6825
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Alere")] <- 6764
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Olua I")] <- 5487
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Boroli 2")] <- 5124
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Mungula I")] <- 4941
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Olua II")] <- 4298
#refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Mungula II")] <- 1593
## the new data only has Oliji as a whole with 1414 population
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Oliji I")] <- 707
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Oliji II")] <- 707
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Elema")] <- 989
## the new data only has Maaji I as a whole with 515 population
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Maaji 1A")] <- 257
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Maaji 1B")] <- 2578


## Check names
all_sites <- colnames(refsites_dist)
all_sites <- gsub(" Distance", "", all_sites)

all(refsites_pop$Name_setlm %in% all_sites)
all(all_sites %in% refsites_pop$Name_setlm)

## Widen
refsites_pop <- refsites_pop %>% 
  pivot_wider(names_from = Name_setlm, values_from = `Refugee Population`) %>%
  mutate(Year = Year + 1)
names(refsites_pop) <- c("Year", paste(names(refsites_pop)[-1], "Population"))

## Final data merge
pol_data_merged <- pol_data_merged %>% left_join(refsites_pop, by = c("year" = "Year"))
nrow(pol_data_merged)

pol_data_merged %>% 
  group_by(P_02_ID, year) %>%
  count() %>%
  arrange(desc(n))

## --------------------
## Fix nearest distance
## --------------------
nd_df <- inner_join(
  pol_data_merged %>%
    dplyr::select(P_02_ID, year, ends_with(" Distance")) %>%
    pivot_longer(cols = ends_with(" Distance"), names_to = "camp", values_to = "distance") %>%
    mutate(camp = gsub(" Distance", "", camp)),
  pol_data_merged %>%
    dplyr::select(P_02_ID, year, ends_with(" Population")) %>%
    pivot_longer(cols = ends_with(" Population"), names_to = "camp", values_to = "population") %>%
    mutate(camp = gsub(" Population", "", camp))
)

min_distance_fixed <- nd_df %>%
  filter(population > 0) %>%
  group_by(P_02_ID, year) %>%
  summarize(min_distance = min(distance))

pol_data_merged <- pol_data_merged %>%
  dplyr::select(-min_distance) %>%
  left_join(min_distance_fixed)

## ------------------------------------
## Construct the shift-share instrument
## ------------------------------------
## 1. Overlay the refugee/country counts onto the parish shapefile,
##    distribute proportionally to overlap
## 2. Calculate delta term 

## Load the data
refsites_pop <- read_csv("uga_refsites_population_final_analysis.csv")
refsites_pop$Year[refsites_pop$Year==2020] <- 2019

## Correct population in Adjumani
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Nyumanzi")] <- 40551
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Pagirinya")] <- 36768
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Ayilo I")] <- 25893
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Maaji II")] <- 17365
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Maaji III")] <- 15366
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Ayilo II")] <- 14506
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Boroli 1")] <- 10049
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Agojo")] <- 7054
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Baratuku")] <- 6921
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Mirieyi")] <- 6825
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Alere")] <- 6764
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Olua I")] <- 5487
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Boroli 2")] <- 5124
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Mungula I")] <- 4941
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Olua II")] <- 4298
#refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Mungula II")] <- 1593
## the new data only has Oliji as a whole with 1414 population
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Oliji I")] <- 707
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Oliji II")] <- 707
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Elema")] <- 989
## the new data only has Maaji I as a whole with 515 population
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Maaji 1A")] <- 257
refsites_pop$`Refugee Population`[(refsites_pop$Year==2019)&(refsites_pop$Name_setlm=="Maaji 1B")] <- 2578

  
refsites_pop = refsites_pop %>%
  dplyr::select(Name_setlm, Year, Burundi, CAR, Chad, Congo, DRC,
                Eritrea, Ethiopia, Iran, Kenya, Liberia, Malawi, Nigeria,
                Rwanda, Senegal, Somalia, `South Sudan`, Sudan, Uganda, Tanzania) %>%
  ## Add Mungula
  add_row(Name_setlm="Mungula II", Year = 2019, `South Sudan` = 1593)%>%
  add_row(Name_setlm="Mungula II", Year = 2015)%>%
  add_row(Name_setlm="Mungula II", Year = 2010)%>%
  add_row(Name_setlm="Mungula II", Year = 2005)%>%
  add_row(Name_setlm="Mungula II", Year = 2000)%>% replace(is.na(.),0) %>%
  pivot_longer(cols = -c(Name_setlm, Year), names_to = "country", 
               values_to = "num_refugees")

## Get site population in 2000
refsites_pop_2000 <- read_csv("uga_refsites_population_final_analysis.csv") %>%
  filter(Year == "2000") %>%
  dplyr::select(Name_setlm, `Refugee Population`) %>%
  rename(settlement_population_2000 = `Refugee Population`) %>%
  add_row(Name_setlm="Mungula II",settlement_population_2000 = 0)

## Do fix to combine Sudan and South Sudan - otherwise 
## South Sudan refugees don't contribute to instrument
refsites_pop <- refsites_pop %>%
  mutate(country = case_when(country == "South Sudan"~"Sudan", 
                             TRUE~country)) %>%
  group_by(Name_setlm, Year, country) %>%
  summarize(num_refugees = sum(num_refugees)) %>%
  ungroup()

## Build movers proportions ### NEED TO FIX
delta_2000 <- refsites_pop %>% 
  filter(Year == "2000") %>%
  group_by(country) %>%
  mutate(delta_is_2000 = num_refugees / sum(num_refugees),
         delta_is_2000 = coalesce(delta_is_2000, 0)) %>%
  dplyr::select(Name_setlm, country, delta_is_2000)
m_df <- refsites_pop %>%
  group_by(Year, country) %>%
  summarize(m_st = sum(num_refugees, na.rm = TRUE))

## Build Z in each year
z_mov_df <- inner_join(delta_2000, m_df) %>%
  group_by(Name_setlm, Year) %>%
  summarize(z_it_mov = sum(m_st * delta_is_2000))

## Cumulatively sum over time
z_df <- z_mov_df %>%
  arrange(Name_setlm, Year) %>%
  group_by(Name_setlm) %>%
  mutate(z_it = cumsum(z_it_mov)) %>%
  ungroup() %>%
  mutate(Year = Year + 1) %>%
  #filter(Year != 2021) %>%
  rename(year = Year)

## Get distances
pol_data_merged_distance <- pol_data_merged %>% 
  dplyr::select(P_02_ID, year, ends_with(" Distance")) %>%
  pivot_longer(cols = ends_with(" Distance"), names_to = "Name_setlm", values_to = "distance") %>%
  mutate(Name_setlm = gsub(" Distance", "", Name_setlm))

pol_data_merged_population <- pol_data_merged %>% 
  dplyr::select(P_02_ID, year, ends_with(" Population")) %>%
  pivot_longer(cols = ends_with(" Population"), names_to = "Name_setlm", values_to = "population") %>%
  mutate(Name_setlm = gsub(" Population", "", Name_setlm))

## Main shift-share
pol_data_merged_shiftshare <- pol_data_merged_distance %>% 
  inner_join(pol_data_merged_population) %>%
  inner_join(z_df) %>%
  mutate(exposure_z = z_it_mov / (distance + 1)) %>%
  group_by(P_02_ID, year) %>%
  filter(population > 0) %>%
  filter(distance == min(distance)) %>%
  filter(population == max(population)) %>%
  rename(nearest_exposure_z = exposure_z, camp = Name_setlm) %>%
  mutate(nearest_exposure_z_ln = log_p1(nearest_exposure_z)) %>%
  dplyr::select(P_02_ID, year, starts_with("nearest_exposure_z"), 
                starts_with("avg_all_exposure_z")) %>% 
  distinct()

## -----------------------------------------
## Shift-share using only camps open in 2001
## -----------------------------------------
camp_open_2001 <- pol_data_merged_population %>%
  filter(year == 2001 & population > 0) %>%
  rename(camp = Name_setlm) %>%
  dplyr::select(year, camp) %>%
  distinct() %>%
  pull(camp)

pol_data_merged_shiftshare_o_01 <- pol_data_merged_distance %>% 
  inner_join(pol_data_merged_population) %>%
  inner_join(z_df) %>%
  inner_join(refsites_pop_2000) %>%
  filter(Name_setlm %in% camp_open_2001) %>%
  mutate(exposure_z = z_it_mov / (distance + 1),
         exposure_z_norm = z_it_mov / settlement_population_2000 / (distance + 1)) %>%
  group_by(P_02_ID, year) %>%
  filter(population > 0) %>%
  filter(distance == min(distance)) %>%
  filter(population == max(population)) %>%
  rename(nearest_exposure_z_01 = exposure_z, nearest_exposure_z_01_norm = exposure_z_norm,
         camp = Name_setlm) %>%
  mutate(nearest_exposure_z_01_ln = log_p1(nearest_exposure_z_01),
         nearest_exposure_z_01_ln_norm = log_p1(nearest_exposure_z_01_norm)) %>%
  dplyr::select(P_02_ID, year, starts_with("nearest_exposure_z_01"), 
                starts_with("avg_all_exposure_z_01")) %>% 
  distinct()

## Merge in
pol_data_merged <- pol_data_merged %>% 
  inner_join(pol_data_merged_shiftshare) %>%
  inner_join(pol_data_merged_shiftshare_o_01)

## -------------------
## Create new measures
## -------------------
exposure_measure_df <- pol_data_merged %>% 
  dplyr::select(year, P_02_ID, D_02_ID, ends_with(" Distance"), ends_with(" Population"))

## Make long df
exposure_measure_df <- inner_join(
  exposure_measure_df %>% dplyr::select(-ends_with(" Population")) %>%
    pivot_longer(cols = ends_with(" Distance"), names_to = "camp", values_to = "distance") %>%
    mutate(camp = gsub(" Distance", "", camp)),
  exposure_measure_df %>% dplyr::select(-ends_with(" Distance")) %>%
    pivot_longer(cols = ends_with(" Population"), names_to = "camp", values_to = "population") %>%
    mutate(camp = gsub(" Population", "", camp))
)

exposure_measure_df <- exposure_measure_df %>%
  inner_join(refsite_district, by = c("camp" = "Name_setlm"))

camp_open_2001 <- exposure_measure_df %>%
  filter(year == 2001 & population > 0) %>%
  dplyr::select(year, camp) %>%
  distinct() %>%
  pull(camp)

## Make measures - all camps
exposure_measure_df_o_all <- exposure_measure_df %>%
  mutate(exposure = population / (distance + 1)) %>%
  group_by(year, P_02_ID) %>%
  filter(population > 0) %>%
  mutate(sum_exposure_20km_rad = coalesce(sum(exposure[distance < 20]), 0),
         sum_exposure_50km_rad = coalesce(sum(exposure[distance < 50]), 0),
         sum_exposure_100km_rad = coalesce(sum(exposure[distance < 100]), 0)) %>%
  filter(distance == min(distance)) %>% ## Now filter to smallest distnace
  filter(population == max(population)) %>% ## To break any remaining ties, take the largest settlement
  rename(nearest_exposure = exposure) %>%
  dplyr::select(-c(camp, distance, population, starts_with("D_02_ID"))) %>% 
  distinct()

## Make measures - just camps open in 2001
exposure_measure_df_o_01 <- exposure_measure_df %>%
  filter(camp %in% camp_open_2001) %>%
  mutate(exposure = population / (distance + 1)) %>%
  group_by(year, P_02_ID) %>%
  filter(population > 0) %>%
  mutate(sum_exposure_01_20km_rad = coalesce(sum(exposure[distance < 20]), 0),
         sum_exposure_01_50km_rad = coalesce(sum(exposure[distance < 50]), 0),
         sum_exposure_01_100km_rad = coalesce(sum(exposure[distance < 100]), 0)) %>%
  filter(distance == min(distance)) %>%
  filter(population == max(population)) %>%
  rename(nearest_exposure_01 = exposure) %>%
  dplyr::select(-c(camp, distance, population, starts_with("D_02_ID"))) %>% 
  distinct()
 
## Merge back to data, rename ID for easier use
pol_data_merged <- pol_data_merged %>% 
  inner_join(exposure_measure_df_o_all) %>%
  inner_join(exposure_measure_df_o_01) %>%
  rename(parish_id = P_02_ID)
nrow(pol_data_merged)

pol_data_merged %>% 
  group_by(parish_id, year) %>%
  count() %>%
  arrange(desc(n))

## Mutate the distance to South Sudan
pol_data_merged <- pol_data_merged %>% 
  rename(distance_to_ssd = `distance_to_ssd (meters)`) %>%
  mutate(distance_to_ssd = distance_to_ssd / 1000)

# Add new variable of min distance in baseline year
pol_data_merged <- pol_data_merged %>%
  left_join(
    pol_data_merged %>% 
      filter(year == 2001) %>% 
      dplyr::select(parish_id, min_distance) %>%
      rename(min_distance_01 = min_distance)
  )

# Wipe 2020 from data for HC columns
pol_data_merged <- pol_data_merged %>%
  mutate(
    across(
      contains("minmax") & contains("_hc"),
      ~case_when(year == 2020~NA_real_, TRUE~.x)
    )
  )

## Output merged dataset
write_csv(pol_data_merged, path = "political_data_merged_Dev_Econ_Paper.csv")

## ----------------------------------
## Look at time varying for each unit
## ----------------------------------

pol_data_merged %>% 
  dplyr::select(parish_id, 
                unemployment_rate_census2002, 
                agriculture_share_census2002, coethnic_share_census2002,
                violent_events, fatalities,
                population_census2002, average_age_census2002, proportion_male_census2002, 
                literacy_rate_census2002) %>%
  pivot_longer(cols = -parish_id) %>%
  group_by(parish_id, name) %>%
  summarize(within_var = var(value)) %>%
  ungroup() %>%
  ggplot(aes(within_var)) + 
  geom_density() + 
  facet_wrap(~name, scales = "free")

pol_data_merged %>% 
  dplyr::select(parish_id, unemployment_rate_census2002, 
                agriculture_share_census2002, coethnic_share_census2002,
                violent_events, fatalities,
                population_census2002, average_age_census2002, proportion_male_census2002, 
                literacy_rate_census2002) %>%
  pivot_longer(cols = -c(parish_id)) %>%
  group_by(parish_id, name) %>%
  summarize(within_var = var(value)) %>%
  ungroup() %>%
  filter(name == "population") %>%
  slice_max(within_var, n = 10)

pol_data_merged$population[pol_data_merged$parish_id == "11330303"]

## ---------
## Make plot
## ---------

## Format refsites
refsites@data$id <- rownames(refsites@data)
refsites_points <- fortify(refsites, region = "id")
refsites_df <- plyr::join(refsites_points, refsites@data, by = "id")

## Format parish
parish@data$id <- rownames(parish@data)
parish_points <- fortify(parish, region = "id")
parish_df <- plyr::join(parish_points, parish@data, by = "id")

## Create plot
ggplot(parish_df, aes(long, lat, group = group, fill = as.factor(pol_match))) + 
    geom_path(color="black", lwd = .05) +
    geom_polygon(alpha = .2) + 
    ## geom_polygon(data = refsites_df, aes(long, lat, group = group),
    ##              alpha = .5, fill = "blue") + 
    theme_void() +
    coord_equal() +
    ggsave("~/Desktop/uganda_refsites.png", height = 6, width = 6)

## -----------------------
## CLEANING CODE GRAVEYARD
## -----------------------
# parish = case_when(parish == "BOOMA WARD"~"BOMA WARD",
#                    parish == "BWAMA IS."~"BWAMA ISLANDS",
#                    parish == "BWAMULAMIRA"~"BWAMURAMIRA",
#                    parish == "CENTRAL- WARD"~"CENTRAL WARD",
#                    parish == "HIMA T/B"~"HIMA TB",
#                    parish == "IREDA-WEST"~"IREDA WEST",
#                    parish == "JUNIOR QUARTERS"~"JUNIOR QUATERS",
#                    parish == "KALEELRE/MALEMBA"~"KALEERE/MALEMBA",
#                    parish == "KALIRO TOWN BOARD"~"KALIRO TB",
#                    parish == "KALIRO-WARD"~"KALIRO WARD",
#                    parish == "KALISIZO TR.C"~"KALISIZO TR",
#                    parish == "KAMUTUR/KAMONGOMERI"~"KOMONGOMERI",
#                    parish == "KASIINA WARD"~"KASIINA",
#                    parish == "KIRONGO WARD"~"KIRONGO",
#                    parish == "KACOC"~"KOCOC",
#                    parish == "LAIPANAT EAST"~"LAPAINAT EAST",
#                    parish == "LOSOGOLO"~"LOSONGOLO",
#                    parish == "LWAKALOLO"~"LWAKALOOLO",
#                    parish == "LWENSINGA"~"LWESINGA",
#                    parish == "LYAMABWA"~"LWAMABWA",
#                    parish == "MWERUKA(KIZIBA)"~"MWERUKA (KIZIBA)",
#                    parish == "NKONKONJERU"~"NKOKONJERU",
#                    parish == "RWIMI"~"RWIIMI",
#                    parish == "TISAI(ISLAND)"~"TISAI (ISLAND)",
#                    TRUE~parish
# ),
# parish = case_when(district == "RAKAI" & county == "KABULA" & scounty == "LYANTONDE" & parish == "KATOVU"~"KATOVU.",
#                    district == "BUSIA" & county == "SAMIA-BUGWE" & scounty == "BUSIA TC" & parish == "SOUTH EAST WARD"~"SOUTH EAST",
#                    district == "RAKAI" & county == "KYOTERA" & scounty == "KABIRA" & parish == "NJARA WARD"~"NJALA",
#                    district == "RAKAI" & county == "KABULA" & scounty == "KINUUKA" & parish == "WABUSANA"~"WABUSAANA",
#                    district == "RAKAI" & county == "KABULA" & scounty == "KALIIRO" & parish == "KALIRO WARD"~"KALIIRO",
#                    TRUE~parish),
# scounty = case_when(district == "KISORO" & county == "BUFUMBIRA" & scounty == "MURORA" & parish == "CHAHAFI"~"CHAHI",
#                     TRUE~scounty),