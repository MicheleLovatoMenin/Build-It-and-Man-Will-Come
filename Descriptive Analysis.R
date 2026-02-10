#########################################################################
### DESCRIPTIVE STATISTICS AND EXPLORATORY ANALYSIS
#########################################################################

library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)

# Set directory
setwd("C:/Users/miklo/Desktop/Geospatial/Build-It-and-Man-Will-Come")
# you have to change your directory

################################################
### 1. DATA LOADING
################################################

s)
raw_sites <- read.csv("datasets/site_fac.csv")

msoa_data <- read.csv("datasets/final_ds.csv") 


################################################
### 2. ANATOMY OF SUPPLY
################################################

# Legend Decoding
facility_codes <- c(
  "1" = "Athletics",
  "2" = "Gym (Health & Fitness)",
  "4" = "Tennis",
  "5" = "Outside Pitch",
  "6" = "Sports Hall",
  "7" = "Swimming Pool",
  "8" = "Outside Pitch",
  "9" = "Golf",
  "10" = "Ice Rinks",
  "11" = "Ski Slope",
  "12" = "Studios",
  "13" = "Squash Court",
  "17" = "Tennis",
  "20" = "Cycling",
  "33" = "Gymnastics"
)

# Separate strings to count every single facility
facilities_exploded <- raw_sites %>%
  select(Site_ID, Facility_Types_List) %>%
  mutate(Type_Code = str_split(Facility_Types_List, ",\\s*")) %>%
  unnest(Type_Code) %>%
  mutate(Type_Code = trimws(Type_Code)) %>%
  filter(Type_Code != "") %>%
  mutate(Type_Label = recode(Type_Code, !!!facility_codes, .default = "Other"))

# Total Counts
total_facilities <- nrow(facilities_exploded)
count_by_type <- facilities_exploded %>%
  group_by(Type_Label) %>%
  summarise(Count = n()) %>%
  mutate(Percent = round(Count / total_facilities * 100, 1)) %>%
  arrange(desc(Count))

print(paste("Total Facilities Census:", total_facilities))
print("Top 5 Facility Types:")
print(head(count_by_type, 5))

################################################
### 3. "MONO-FOOTBALL" MSOA ANALYSIS
################################################
# Question: How many neighborhoods have ONLY football and nothing else?

football_codes <- c("5", "8") # 5=Grass, 8=Synthetic

# Analyze row by row the MSOA dataset (final_ds.csv)
msoa_analysis <- msoa_data %>%
  rowwise() %>%
  mutate(
    codes_vec = list(trimws(unlist(str_split(Type_List_Inside, ",\\s*")))),
    codes_vec = list(codes_vec[codes_vec != ""]),
    n_facilities = length(codes_vec),
    
    # Check Mono-Football:
    # - Must have at least one facility (n > 0)
    # - ALL facilities must be in the football_codes list (5 or 8)
    is_mono_football = (n_facilities > 0) & all(codes_vec %in% football_codes)
  ) %>%
  ungroup()

# Consider only MSOAs with at least one facility (exclude total empty ones)
msoa_with_facilities <- msoa_analysis %>% filter(n_facilities > 0)

num_total_active_msoa <- nrow(msoa_with_facilities)
num_mono_msoa <- sum(msoa_with_facilities$is_mono_football)
perc_mono_msoa <- round(num_mono_msoa / num_total_active_msoa * 100, 1)

print(paste("Total MSOAs:", nrow(msoa_data)))
print(paste("MSOAs with at least one facility:", num_total_active_msoa))
print(paste("MSOAs without any sports facility:", nrow(msoa_data)-num_total_active_msoa))
print(paste("Mono-Football MSOAs (Football Only):", num_mono_msoa))
print(paste("Percentage Mono-Football MSOAs:", perc_mono_msoa, "%"))


# ARE MONO-FOOTBALL MSOAs POORER?
# Compare average wealth (NS_1_2) between Mono-Football MSOAs and Diverse MSOAs
wealth_comparison <- msoa_with_facilities %>%
  group_by(is_mono_football) %>%
  summarise(
    Avg_Wealth = mean(NS_1_2_prop, na.rm=TRUE),
    Avg_Inactive = mean(Inactive_All_adults, na.rm=TRUE),
    Avg_Active = mean(Active_All_adults, ns.rm=TRUE),
    Avg_Gender_gap_Act = mean(Gender_Gap_Active, ns.rm=TRUE),
    Avg_Gender_gap_Inact = mean(Gender_Gap_Inactive, ns.rm=TRUE),
    Count = n()
  ) %>%
  mutate(Label = ifelse(is_mono_football, "Mono-Football MSOA", "Diverse MSOA"))

print("--- WEALTH AND INACTIVITY COMPARISON ---")
print(wealth_comparison)


################################################
### 4. ANATOMY OF THE GENDER GAP
################################################

# Basic statistics
mean_gap <- mean(msoa_data$Gender_Gap_Active, na.rm=TRUE)
median_gap <- median(msoa_data$Gender_Gap_Active, na.rm=TRUE)
max_gap <- max(msoa_data$Gender_Gap_Active, na.rm=TRUE)
min_gap <- min(msoa_data$Gender_Gap_Active, na.rm=TRUE)

# How many zones have women more active than men? (Gap < 0)
female_advantage_count <- sum(msoa_data$Gender_Gap_Active < 0, na.rm=TRUE)
female_advantage_perc <- round(female_advantage_count / nrow(msoa_data) * 100, 2)

print(paste("Average Gender Gap (Men - Women):", round(mean_gap * 100, 2), "%")) # Assuming decimals
print(paste("Zones where women are more active:", female_advantage_count, "(", female_advantage_perc, "%)"))

# inactive

mean_gap <- mean(msoa_data$Gender_Gap_Inactive, na.rm=TRUE)
median_gap <- median(msoa_data$Gender_Gap_Inactive, na.rm=TRUE)
max_gap <- max(msoa_data$Gender_Gap_Inactive, na.rm=TRUE)
min_gap <- min(msoa_data$Gender_Gap_Inactive, na.rm=TRUE)

# How many zones have women more inactive than men? (Gap > 0)
female_advantage_count_in <- sum(msoa_data$Gender_Gap_Inactive > 0, na.rm=TRUE)
female_advantage_perc_in <- round(female_advantage_count_in / nrow(msoa_data) * 100, 2)

print(paste("Average Gender Gap Inactive (Men - Women):", round(mean_gap * 100, 2), "%")) # Assuming decimals
print(paste("Zones where women are more inactive:", female_advantage_count_in, "(", female_advantage_perc_in, "%)"))

################################################
### 5. SUPPLY VS DEMAND (Rich vs Poor)
################################################
print("--- SPATIAL INEQUALITY (Rich vs Poor) ---")

# Divide MSOAs into 4 Quartiles based on Wealth (NS_1_2_prop)
# Q1 = Poorest (Bottom 25%), Q4 = Richest (Top 25%)

msoa_data <- msoa_data %>%
  mutate(Wealth_Quartile = ntile(NS_1_2_prop, 4)) %>%
  mutate(Class_Label = case_when(
    Wealth_Quartile == 4 ~ "High Wealth (Top 25%)",
    Wealth_Quartile == 1 ~ "Low Wealth (Bottom 25%)",
    TRUE ~ "Middle"
  ))

# Means Comparison
inequality_stats <- msoa_data %>%
  filter(Class_Label != "Middle") %>%
  group_by(Class_Label) %>%
  summarise(
    Avg_Facilities = mean(Facilities_Inside, na.rm=TRUE),
    Avg_Diversity = mean(Diversity_Index_Inside, na.rm=TRUE),
    Avg_Active_Adults = mean(Active_All_adults, na.rm=TRUE),
    Avg_Inactive_Adults = mean(Inactive_All_adults, na.rm=TRUE),
    Avg_Gender_Gap = mean(Gender_Gap_Active, na.rm=TRUE)
  )

print(inequality_stats)


################################################
### 5. PLOTS
################################################

# Plot 1: Bar Chart of Supply
# (Save only top 6 and group the rest into "Other")
top_facilities <- count_by_type %>%
  mutate(Type_Label = ifelse(rank(desc(Count)) <= 6, Type_Label, "Other Facilities")) %>%
  group_by(Type_Label) %>%
  summarise(Count = sum(Count))

ggplot(top_facilities, aes(x = reorder(Type_Label, -Count), y = Count, fill=Type_Label)) +
  geom_bar(stat = "identity") +
  theme_minimal() +
  labs(title = "Sports Infrastructure Composition",
       x = "Typology", y = "Total Number of Facilities") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Plot 2: Active_adults by Social Class
ggplot(msoa_data, aes(x = as.factor(Wealth_Quartile), y = Active_All_adults)) +
  geom_boxplot(fill = "lightblue", alpha = 0.7) +
  labs(title = "Share of inhabitants practicing sport",
       x = "Wealth Quartile (NS Sec 1-2)",
       y = "Active All Adults") +
  theme_minimal()

# Plot 3: Inactive_adults by Social Class
ggplot(msoa_data, aes(x = as.factor(Wealth_Quartile), y = Inactive_All_adults)) +
  geom_boxplot(fill = "lightpink", alpha = 0.7) +
  labs(title = "Share of inhabitants not practicing sport",
       x = "Wealth Quartile (NS Sec 1-2)",
       y = "Inactive All Adults") +
  theme_minimal()

# Plot 4: Number of Facilities by Social Class
ggplot(msoa_data, aes(x = as.factor(Wealth_Quartile), y = Facilities_Inside)) +
  geom_boxplot(fill = "lightgreen", alpha = 0.7) +
  labs(title = "Distribution of Sports Facilities by Wealth",
       x = "Wealth Quartile (NS Sec 1-2)",
       y = "Number of Facilities") +
  theme_minimal()

