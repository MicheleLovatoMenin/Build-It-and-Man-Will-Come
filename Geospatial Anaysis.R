#########################################################################
### GEOSPATIAL PROJECT: INFRASTRUCTURE AND PHYSICAL ACTIVITY
#########################################################################

# LIBRARIES
library(sf)
library(tmap)        
library(spdep)       
library(spatialreg)  
library(dplyr)
library(ggplot2)

#########################################################################
### FAST LOADING OF ALL PROJECT ASSETS
#########################################################################

# Set Working Directory
setwd("C:/Users/miklo/Desktop/Geospatial/Build-It-and-Man-Will-Come")
# you have to change your directory

# 1. SPATIAL WEIGHTS
listw_idw <- readRDS("output_models/listw_idw.rds")

# 2. BASE MODELS (Naive & Full)
sdem_naive <- readRDS("output_models/sdem_naive.rds")
sdm_naive  <- readRDS("output_models/sdm_naive.rds")

sdm_full   <- readRDS("output_models/sdm_full.rds")
sem_full   <- readRDS("output_models/sem_full.rds")
sar_full   <- readRDS("output_models/sar_full.rds")
sdem_full  <- readRDS("output_models/sdem_full.rds")

# 3. MAIN IMPACTS (Full SDEM)
impacts_sdem <- readRDS("output_models/impacts_sdem.rds")

# 4. ROBUSTNESS CHECKS (K-NN & Sites)
sdem_k20    <- readRDS("output_models/sdem_k20.rds")
impacts_k20 <- readRDS("output_models/impacts_k20.rds")

sdem_k50    <- readRDS("output_models/sdem_k50.rds")
impacts_k50 <- readRDS("output_models/impacts_k50.rds")

sdem_sites    <- readRDS("output_models/sdem_sites.rds")
impacts_sites <- readRDS("output_models/impacts_sites.rds")

# 5. DIVERSITY ANALYSIS
sdem_diversity    <- readRDS("output_models/sdem_diversity.rds")
impacts_diversity <- readRDS("output_models/impacts_diversity.rds")

# 6. NO FOOTBALL
sdem_no_football <- readRDS("output_models/sdem_no_football.rds")
impacts_no_football <- readRDS("output_models/impacts_no_football.rds")

# 7. INACTIVE ANALYSIS
sdem_inactive    <- readRDS("output_models/sdem_inactive.rds")
impacts_inactive <- readRDS("output_models/impacts_inactive.rds")

# 8. INACTIVE - DIVERSITY
sdem_inact_div    <- readRDS("output_models/sdem_inact_div.rds")
impacts_inact_div <- readRDS("output_models/impacts_inact_div.rds")

# 9. GENDER ANALYSIS: ACTIVE vs DIVERSITY
sdem_male_div   <- readRDS("output_models/sdem_male_div.rds")
sdem_female_div <- readRDS("output_models/sdem_female_div.rds")
sdem_gap_div    <- readRDS("output_models/sdem_gap_div.rds")
impacts_male_div <- readRDS("output_models/impacts_male_div.rds")
impacts_female_div <- readRDS("output_models/impacts_female_div.rds")
impacts_gap_div <- readRDS("output_models/impacts_gap_div.rds")

# 10. GENDER ANALYSIS: ACTIVE vs FACILITIES
sdem_male_fac   <- readRDS("output_models/sdem_male_fac.rds")
sdem_female_fac <- readRDS("output_models/sdem_female_fac.rds")
sdem_gap_fac    <- readRDS("output_models/sdem_gap_fac.rds")
impacts_male_fac <- readRDS("output_models/impacts_male_fac.rds")
impacts_female_fac <- readRDS("output_models/impacts_female_fac.rds")
impacts_gap_fac <- readRDS("output_models/impacts_gap_fac.rds")

# 11. GENDER ANALYSIS: INACTIVE vs FACILITIES
sdem_gap_inact_fac       <- readRDS("output_models/sdem_gap_inact_fac.rds")
impacts_gap_inact_fac    <- readRDS("output_models/impacts_gap_inact_fac.rds")

# 12. GENDER ANALYSIS: INACTIVE vs DIVERSITY
sdem_gap_inact_div       <- readRDS("output_models/sdem_gap_inact_div.rds")
impacts_gap_inact_div    <- readRDS("output_models/impacts_gap_inact_div.rds")

print("All models and impacts loaded successfully.")



################################################
### 1. DATA LOADING AND PREPARATION
################################################

# A. Load Shapefile and CSV
shp <- st_read("datasets/middle_layer/MSOA_2021_EW_BGC_V3.shp")
data_csv <- read.csv("datasets/final_ds.csv")

# B. Merge
map_data <- merge(shp, data_csv, by.x = "MSOA21CD", by.y = "MSOA.code")
map_data <- st_as_sf(map_data) 

# C. Variable Selection
vars_to_keep <- c("MSOA21CD", "Active_All_adults", "Inactive_All_adults",
                  "Active_Male", "Active_Female", "Gender_Gap_Active", 
                  "Inactive_Male", "Inactive_Female", "Gender_Gap_Inactive",
                  "Facilities_Inside", "Sites_Inside",
                  "Diversity_Index_Inside", "Facilities_Inside_No_Football",
                  "NS_1_2_prop", "NS_3_prop", "NS_4_prop", "NS_5_prop", 
                  "NS_6_7_prop", "NS_8_prop", "NS_9_prop",
                  "Age_16_34_prop", "Age_35_54_prop", "Age_55_74_prop", "Age_75._prop",
                  "Asian_prop", "Black_prop", "Mixed_prop", "Other_prop", "White_prop",
                  "geometry")

model_data <- map_data[, vars_to_keep]
map_data_clean <- na.omit(model_data)

print(paste("Dataset ready. Rows:", nrow(map_data_clean)))

################################################
### 2. SPATIAL WEIGHTS MATRIX
################################################

# Hybrid strategy: KNN + Cutoff 15km + IDW Weights
k_limit <- 10        
dist_limit <- 15000  

coords <- st_centroid(st_geometry(map_data_clean))
knn <- knearneigh(coords, k = k_limit)
nb_knn <- knn2nb(knn)
dists <- nbdists(nb_knn, coords)

# Hybrid IDW Function
geo_data <- mapply(function(ids, d) {
  valid <- d <= dist_limit
  if(sum(valid) == 0) {
    return(list(ids = as.integer(0), weights = numeric(0))) 
  } else {
    weights <- 1 / (d[valid] / 1000 + 0.001) # IDW
    return(list(ids = ids[valid], weights = weights))
  }
}, nb_knn, dists, SIMPLIFY = FALSE)

nb_final <- lapply(geo_data, function(x) x$ids)
w_final  <- lapply(geo_data, function(x) x$weights)

attributes(nb_final) <- attributes(nb_knn)
class(nb_final) <- "nb"

# Create Listw
listw_idw <- nb2listw(nb_final, glist = w_final, style = "W", zero.policy = TRUE)
print("Hybrid IDW Spatial Matrix created.")

# Save Matrix
saveRDS(listw_idw, file = "output_models/listw_idw.rds")

################################################
### 3. Exploratory Spatial Data Analysis
################################################

# Global Moran's I
moran_global <- moran.test(map_data_clean$Active_All_adults, listw_idw)
print(moran_global)

# Monte Carlo Simulation
set.seed(123) 
moran_mc <- moran.mc(map_data_clean$Active_All_adults, listw_idw, nsim=999)
print(moran_mc)

# Moran Scatterplot
moran.plot(map_data_clean$Active_All_adults, listw_idw, 
           main="Moran Scatterplot - Active Adults", 
           xlab="Physical Activity", ylab="Spatial Lag of Physical Activity")

# Enhanced Moran Plot with ggplot2
moran_df <- data.frame(
  x = map_data_clean$Active_All_adults,
  wx = lag.listw(listw_idw, map_data_clean$Active_All_adults)
)
moran_df_clean <- subset(moran_df, wx > 0)

ggplot(moran_df_clean, aes(x = x, y = wx)) +
  geom_point(alpha = 0.3, size = 1.5, color = "darkblue") + 
  geom_smooth(method = "lm", color = "red", se = FALSE) + 
  geom_vline(xintercept = mean(moran_df_clean$x), linetype = "dashed", color = "grey") +
  geom_hline(yintercept = mean(moran_df_clean$wx), linetype = "dashed", color = "grey") +
  labs(title = "Moran Scatterplot - Physical Activity",
       subtitle = paste("Removed", nrow(moran_df) - nrow(moran_df_clean), "isolated zones (Lag=0)"),
       x = "Physical Activity",
       y = "Spatial Lag of Physical Activity") +
  theme_minimal()

################################################
### 3. LOCAL CLUSTER MAPS (LISA)
################################################

loc_moran <- localmoran(map_data_clean$Active_All_adults, listw_idw)
quadrant_base <- attr(loc_moran, "quadr")$mean

# Standard (p < 0.05)
map_data_clean$quadrant_std <- quadrant_base
p_vals_std <- loc_moran[, 5]
map_data_clean$quadrant_std[p_vals_std > 0.05] <- NA 

# Bonferroni (Robust)
map_data_clean$quadrant_bonf <- quadrant_base
p_vals_adj <- p.adjust(p_vals_std, method = "bonferroni")
map_data_clean$quadrant_bonf[p_vals_adj > 0.05] <- NA 

tmap_mode("plot")

map1 <- tm_shape(map_data_clean) + 
  tm_polygons("quadrant_std", title="LISA (P < 0.05)", 
              palette = c("red", "pink", "lightblue", "blue"),
              lwd = 0, border.alpha = 0.1,
              textNA = "Not Significant", colorNA = "grey95") +
  tm_layout(main.title = "Regional Trends", frame = FALSE)

map2 <- tm_shape(map_data_clean) + 
  tm_polygons("quadrant_bonf", title="LISA (Bonferroni)", 
              palette = c("red", "pink", "lightblue", "blue"),
              lwd = 0, border.alpha = 0.1,
              textNA = "Not Significant", colorNA = "grey95") +
  tm_layout(main.title = "Robust Hotspots", frame = FALSE)

tmap_arrange(map1, map2, ncol = 2)

print(paste("Standard Clusters :", sum(!is.na(map_data_clean$quadrant_std))))
print(paste("Bonferroni Clusters:", sum(!is.na(map_data_clean$quadrant_bonf))))


################################################
### 4. NAIVE MODEL (Infrastructure Only)
################################################

# OLS naive
ols_naive <- lm(Active_All_adults ~ Facilities_Inside, data = map_data_clean)
summary(ols_naive)

lm_tests_naive <- lm.RStests(ols_naive, listw_idw, test=c("LMerr", "LMlag", "RLMerr", "RLMlag"))
print("LM Tests for Model Selection (Naive):")
summary(lm_tests_naive)

# SDEM Naive
sdem_naive <- errorsarlm(Active_All_adults ~ Facilities_Inside, 
                         data = map_data_clean, 
                         listw = listw_idw, 
                         Durbin = TRUE, 
                         zero.policy = TRUE)

summary(sdem_naive)
saveRDS(sdem_naive, file = "output_models/sdem_naive.rds")

## SDM naive
sdm_naive <- lagsarlm(Active_All_adults ~ Facilities_Inside, 
                      data = map_data_clean, 
                      listw = listw_idw, 
                      Durbin = TRUE, 
                      zero.policy = TRUE)

summary(sdm_naive)
saveRDS(sdm_naive, file = "output_models/sdm_naive.rds")

################################################
### 5. FULL SOCIO-ECONOMIC MODEL
################################################

formula_full <- Active_All_adults ~ Facilities_Inside + 
  NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop +
  Age_35_54_prop + Age_55_74_prop + Age_75._prop +
  Asian_prop + Black_prop + Mixed_prop + Other_prop

# ols
ols_full <- lm(formula_full, data = map_data_clean)

# lm test
lm_tests_full <- lm.RStests(ols_full, listw_idw, test=c("LMerr", "LMlag", "RLMerr", "RLMlag"))
summary(lm_tests_full)

# estimate all models for comparison

# SDM
sdm_full <- lagsarlm(formula_full, data = map_data_clean, listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
# summary(sdm_full)

# SEM
sem_full <- errorsarlm(formula_full, data = map_data_clean, listw = listw_idw, Durbin = FALSE, zero.policy = TRUE)
# summary(sem_full)

# SAR
sar_full <- lagsarlm(formula_full, data = map_data_clean, listw = listw_idw, Durbin = FALSE, zero.policy = TRUE)
# summary(sar_full)

# SDEM
sdem_full <- errorsarlm(formula_full, data = map_data_clean, listw = listw_idw, Durbin = TRUE, etype = "error", zero.policy = TRUE)
# summary(sdem_full)

# Saving
saveRDS(sdm_full, file = "output_models/sdm_full.rds")
saveRDS(sem_full, file = "output_models/sem_full.rds")
saveRDS(sar_full, file = "output_models/sar_full.rds")
saveRDS(sdem_full, file = "output_models/sdem_full.rds")

################################################
### 6. MODEL SELECTION (LR TESTS & ANOVA & AIC)
################################################


lr_sdm_sem <- anova(sem_full, sdm_full) 
print("LR Test: SDM vs SEM")
print(lr_sdm_sem)

lr_sdm_sar <- anova(sar_full, sdm_full)
print("LR Test: SDM vs SAR")
print(lr_sdm_sar)

# AIC comparison
aic_vals <- AIC(ols_full, sdm_full, sem_full, sar_full, sdem_full)
aic_vals$Model_Name <- row.names(aic_vals)
aic_vals <- aic_vals[order(aic_vals$AIC), ]

print(aic_vals)
print(paste("Best AIC:", row.names(aic_vals)[1]))

# Summary SDEM (best model)
summary(sdem_full)

# residuals SDEM
map_data_clean$res_sdem <- residuals(sdem_full)

moran_sdem_res <- moran.test(map_data_clean$res_sdem, listw_idw)
print("Moran's I on SDEM Residuals (Should be clean):")
print(moran_sdem_res)

# residual OLS

lm_moran_res <- lm.morantest(ols_full, listw_idw)
print("Moran's I Test on OLS Residuals:")
print(lm_moran_res)

################################################
### 7. RESIDUALS PLOT
################################################

# Residuals OLS plot
map_data_clean$res_ols <- rstudent(ols_full)
tm_shape(map_data_clean) + 
  tm_polygons("res_ols", 
              breaks = c(-4, -2, -0.5, -0.1, 0, 0.1, 0.5, 2, 4),
              palette = "-RdBu", 
              title = "OLS Residuals",
              lwd = 0, border.alpha = 0.1,
              midpoint = 0) +
  tm_layout(main.title = "Spatial Dependence in OLS Residuals", frame = FALSE)

# Residuals SDEM plot
map_data_clean$res_sdem <- residuals(sdem_full)
tm_shape(map_data_clean) + 
  tm_polygons("res_sdem", 
              palette = "-RdBu",
              breaks = c(-4, -2, -0.5, -0.1, 0, 0.1, 0.5, 2, 4),
              title = "SDEM Residuals",
              lwd = 0, border.alpha = 0.1,
              midpoint = 0) +
  tm_layout(main.title = "Spatial Independence in SDEM Residuals", frame = FALSE)

################################################
### 8. IMPACTS CALCULATION
################################################

impacts_sdem <- impacts(sdem_full, listw = listw_idw, R = 1000)
summary(impacts_sdem, zstats=TRUE, short=TRUE)
saveRDS(impacts_sdem, file = "output_models/impacts_sdem.rds")

################################################
### 9. ROBUSTNESS CHECKS (SENSITIVITY ANALYSIS)
################################################

# Function to create custom spatial weights
make_weights <- function(data, k_val, dist_val) {
  coords_check <- st_centroid(st_geometry(data))
  knn_check <- knearneigh(coords_check, k = k_val)
  nb_knn_check <- knn2nb(knn_check)
  dists_check <- nbdists(nb_knn_check, coords_check)
  
  geo_data_check <- mapply(function(ids, d) {
    valid <- d <= dist_val
    if(sum(valid) == 0) return(list(ids = as.integer(0), weights = numeric(0)))
    weights <- 1 / (d[valid] / 1000 + 0.001)
    return(list(ids = ids[valid], weights = weights))
  }, nb_knn_check, dists_check, SIMPLIFY = FALSE)
  
  nb_check <- lapply(geo_data_check, function(x) x$ids)
  w_check  <- lapply(geo_data_check, function(x) x$weights)
  attributes(nb_check) <- attributes(nb_knn_check)
  class(nb_check) <- "nb"
  
  return(nb2listw(nb_check, glist = w_check, style = "W", zero.policy = TRUE))
}

# KNN = 20
listw_k20 <- make_weights(map_data_clean, k_val=20, dist_val=15000)
sdem_k20 <- errorsarlm(formula_full, data = map_data_clean, listw = listw_k20, 
                       Durbin = TRUE, zero.policy = TRUE)

summary(sdem_k20)
saveRDS(sdem_k20, file = "output_models/sdem_k20.rds")

# Calculating Impacts
impacts_k20 <- impacts(sdem_k20, listw = listw_k20, R = 1000, zero.policy = TRUE)
saveRDS(impacts_k20, file = "output_models/impacts_k20.rds")
summary(impacts_k20, zstats=TRUE, short=TRUE)

# KNN = 50
listw_k50 <- make_weights(map_data_clean, k_val=50, dist_val=15000)
sdem_k50 <- errorsarlm(formula_full, data = map_data_clean, listw = listw_k50, 
                       Durbin = TRUE, zero.policy = TRUE)

summary(sdem_k50)
saveRDS(sdem_k50, file = "output_models/sdem_k50.rds")

# Calculating Impacts
impacts_k50 <- impacts(sdem_k50, listw = listw_k50, R = 1000, zero.policy = TRUE)
saveRDS(impacts_k50, file = "output_models/impacts_k50.rds")
summary(impacts_k50, zstats=TRUE, short=TRUE)

# sites vs facilities
formula_sites <- Active_All_adults ~ Sites_Inside + 
  NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop +
  Age_35_54_prop + Age_55_74_prop + Age_75._prop +
  Asian_prop + Black_prop + Mixed_prop + Other_prop

sdem_sites <- errorsarlm(formula_sites, data = map_data_clean, listw = listw_idw, 
                         Durbin = TRUE, zero.policy = TRUE)

summary(sdem_sites)
saveRDS(sdem_sites, file = "output_models/sdem_sites.rds")

# Calculating Impacts
impacts_sites <- impacts(sdem_sites, listw = listw_idw, R = 1000, zero.policy = TRUE)
saveRDS(impacts_sites, file = "output_models/impacts_sites.rds")
summary(impacts_sites, zstats=TRUE, short=TRUE)

################################################
### 10: DIVERSITY INDEX ANALYSIS
################################################

formula_diversity <- Active_All_adults ~ Diversity_Index_Inside + 
  NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop +
  Age_35_54_prop + Age_55_74_prop + Age_75._prop +
  Asian_prop + Black_prop + Mixed_prop + Other_prop

# Estimation (SDEM)
sdem_diversity <- errorsarlm(formula_diversity, data = map_data_clean, 
                             listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
summary(sdem_diversity)
saveRDS(sdem_diversity, file = "output_models/sdem_diversity.rds")

impacts_diversity <- impacts(sdem_diversity, listw = listw_idw, R = 10000, zero.policy = TRUE)
summary(impacts_diversity, zstats=TRUE, short=TRUE)
saveRDS(impacts_diversity, file = "output_models/impacts_diversity.rds")

################################################
### 11. NO-FOOTBALL ANALYSIS
################################################

formula_no_football <- Active_All_adults ~ Facilities_Inside_No_Football + 
  NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop +
  Age_35_54_prop + Age_55_74_prop + Age_75._prop +
  Asian_prop + Black_prop + Mixed_prop + Other_prop

# Estimation (SDEM)
sdem_no_football <- errorsarlm(formula_no_football, data = map_data_clean, 
                               listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
summary(sdem_no_football)
saveRDS(sdem_no_football, file = "output_models/sdem_no_football.rds")

impacts_no_football <- impacts(sdem_no_football, listw = listw_idw, R = 1000, zero.policy = TRUE)
summary(impacts_no_football, zstats=TRUE, short=TRUE)
saveRDS(impacts_no_football, file = "output_models/impacts_no_football.rds")

################################################
### 12. INACTIVE ANALYSIS
################################################

formula_inactive <- Inactive_All_adults ~ Facilities_Inside + 
  NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop +
  Age_35_54_prop + Age_55_74_prop + Age_75._prop +
  Asian_prop + Black_prop + Mixed_prop + Other_prop

# Estimation (SDEM)
sdem_inactive <- errorsarlm(formula_inactive, data = map_data_clean, 
                            listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
summary(sdem_inactive)
saveRDS(sdem_inactive, file = "output_models/sdem_inactive.rds")

impacts_inactive <- impacts(sdem_inactive, listw = listw_idw, R = 1000, zero.policy = TRUE)
summary(impacts_inactive, zstats=TRUE, short=TRUE)
saveRDS(impacts_inactive, file = "output_models/impacts_inactive.rds")

################################################
### 13. INACTIVE ANALYSIS ON DIVERSITY
################################################

formula_inact_div <- Inactive_All_adults ~ Diversity_Index_Inside + 
  NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop +
  Age_35_54_prop + Age_55_74_prop + Age_75._prop +
  Asian_prop + Black_prop + Mixed_prop + Other_prop

# Estimation (SDEM)
sdem_inact_div <- errorsarlm(formula_inact_div, data = map_data_clean, listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)

saveRDS(sdem_inact_div, file = "output_models/sdem_inact_div.rds")
summary(sdem_inact_div)

# Impact Calculation
impacts_inact_div <- impacts(sdem_inact_div, listw = listw_idw, R = 1000, zero.policy = TRUE)
saveRDS(impacts_inact_div, file = "output_models/impacts_inact_div.rds")
summary(impacts_inact_div, zstats = TRUE, short = TRUE)

################################################
### 14. GENDER ANALYSIS (FACILITIES)
################################################

formula_male_fac <- Active_Male ~ Facilities_Inside + NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop + Age_35_54_prop + Age_55_74_prop + Age_75._prop + Asian_prop + Black_prop + Mixed_prop + Other_prop
sdem_male_fac <- errorsarlm(formula_male_fac, data = map_data_clean, listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
saveRDS(sdem_male_fac, file = "output_models/sdem_male_fac.rds")
impacts_male_fac <- impacts(sdem_male_fac, listw = listw_idw, R = 1000, zero.policy = TRUE)
saveRDS(impacts_male_fac, file = "output_models/impacts_male_fac.rds")

formula_female_fac <- Active_Female ~ Facilities_Inside + NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop + Age_35_54_prop + Age_55_74_prop + Age_75._prop + Asian_prop + Black_prop + Mixed_prop + Other_prop
sdem_female_fac <- errorsarlm(formula_female_fac, data = map_data_clean, listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
saveRDS(sdem_female_fac, file = "output_models/sdem_female_fac.rds")
impacts_female_fac <- impacts(sdem_female_fac, listw = listw_idw, R = 1000, zero.policy = TRUE)
saveRDS(impacts_female_fac, file = "output_models/impacts_female_fac.rds")

formula_gap_fac <- Gender_Gap_Active ~ Facilities_Inside + NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop + Age_35_54_prop + Age_55_74_prop + Age_75._prop + Asian_prop + Black_prop + Mixed_prop + Other_prop
sdem_gap_fac <- errorsarlm(formula_gap_fac, data = map_data_clean, listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
saveRDS(sdem_gap_fac, file = "output_models/sdem_gap_fac.rds")
impacts_gap_fac <- impacts(sdem_gap_fac, listw = listw_idw, R = 1000, zero.policy = TRUE)
saveRDS(impacts_gap_fac, file = "output_models/impacts_gap_fac.rds")

summary(sdem_male_fac)
summary(sdem_female_fac)
summary(sdem_gap_fac)

summary(impacts_male_fac)
summary(impacts_female_fac)
summary(impacts_gap_fac)

################################################
### 15. GENDER ANALYSIS (DIVERSITY)
################################################

formula_male <- Active_Male ~ Diversity_Index_Inside + NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop + Age_35_54_prop + Age_55_74_prop + Age_75._prop + Asian_prop + Black_prop + Mixed_prop + Other_prop
sdem_male_div <- errorsarlm(formula_male, data = map_data_clean, listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
saveRDS(sdem_male_div, file = "output_models/sdem_male_div.rds")
impacts_male_div <- impacts(sdem_male_div, listw = listw_idw, R = 1000, zero.policy = TRUE)
saveRDS(impacts_male_div, file = "output_models/impacts_male_div.rds")

formula_female <- Active_Female ~ Diversity_Index_Inside + NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop + Age_35_54_prop + Age_55_74_prop + Age_75._prop + Asian_prop + Black_prop + Mixed_prop + Other_prop
sdem_female_div <- errorsarlm(formula_female, data = map_data_clean, listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
saveRDS(sdem_female_div, file = "output_models/sdem_female_div.rds")
impacts_female_div <- impacts(sdem_female_div, listw = listw_idw, R = 1000, zero.policy = TRUE)
saveRDS(impacts_female_div, file = "output_models/impacts_female_div.rds")

formula_gap <- Gender_Gap_Active ~ Diversity_Index_Inside + NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop + Age_35_54_prop + Age_55_74_prop + Age_75._prop + Asian_prop + Black_prop + Mixed_prop + Other_prop
sdem_gap_div <- errorsarlm(formula_gap, data = map_data_clean, listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
saveRDS(sdem_gap_div, file = "output_models/sdem_gap_div.rds")
impacts_gap_div <- impacts(sdem_gap_div, listw = listw_idw, R = 1000, zero.policy = TRUE)
saveRDS(impacts_gap_div, file = "output_models/impacts_gap_div.rds")

summary(sdem_male_div)
summary(sdem_female_div)
summary(sdem_gap_div)

summary(impacts_male_div)
summary(impacts_female_div)
summary(impacts_gap_div)

################################################
### 16. GENDER ANALYSIS / INACTIVITY
################################################

# Facilities

formula_gap_inact_fac <- Gender_Gap_Inactive ~ Facilities_Inside + 
  NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop +
  Age_35_54_prop + Age_55_74_prop + Age_75._prop +
  Asian_prop + Black_prop + Mixed_prop + Other_prop

sdem_gap_inact_fac <- errorsarlm(formula_gap_inact_fac, data = map_data_clean, listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
saveRDS(sdem_gap_inact_fac, file = "output_models/sdem_gap_inact_fac.rds")
summary(sdem_gap_inact_fac)

impacts_gap_inact_fac <- impacts(sdem_gap_inact_fac, listw = listw_idw, R = 1000, zero.policy = TRUE)
saveRDS(impacts_gap_inact_fac, file = "output_models/impacts_gap_inact_fac.rds")
summary(impacts_gap_inact_fac, zstats = TRUE, short = TRUE)

# Diversity

formula_gap_inact_div <- Gender_Gap_Inactive ~ Diversity_Index_Inside + 
  NS_1_2_prop + NS_4_prop + NS_5_prop + NS_6_7_prop + NS_8_prop + NS_9_prop +
  Age_35_54_prop + Age_55_74_prop + Age_75._prop +
  Asian_prop + Black_prop + Mixed_prop + Other_prop

sdem_gap_inact_div <- errorsarlm(formula_gap_inact_div, data = map_data_clean, listw = listw_idw, Durbin = TRUE, zero.policy = TRUE)
saveRDS(sdem_gap_inact_div, file = "output_models/sdem_gap_inact_div.rds")
summary(sdem_gap_inact_div)

impacts_gap_inact_div <- impacts(sdem_gap_inact_div, listw = listw_idw, R = 1000, zero.policy = TRUE)
saveRDS(impacts_gap_inact_div, file = "output_models/impacts_gap_inact_div.rds")
summary(impacts_gap_inact_div, zstats = TRUE, short = TRUE)


