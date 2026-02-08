import pandas as pd
import numpy as np

# =========================================
# 1. Data Loading
# =========================================

df_site_sport = pd.read_csv('datasets/site_sport.csv')
df_census_eth = pd.read_csv('datasets/census_ethnic_msoa.csv')
df_census_age = pd.read_csv('datasets/census_age_msoa.csv')
df_census_job = pd.read_csv('datasets/census_job_msoa.csv')

# ==========================================
# 2. Process Ethnicity
# ==========================================

# Census Data Extraction and Aggregation (Weights and Percentages)
census_prep = pd.DataFrame()
census_prep['MSOA_Code_Join'] = df_census_eth['geography code']
census_prep['Pop_Total'] = df_census_eth['Ethnic group: Total: All usual residents']

# --- Macro Groups (Absolute Totals) ---
census_prep['Pop_Asian_Total'] = df_census_eth['Ethnic group: Asian, Asian British or Asian Welsh']
census_prep['Pop_Black_Total'] = df_census_eth['Ethnic group: Black, Black British, Black Welsh, Caribbean or African']
census_prep['Pop_Mixed_Total'] = df_census_eth['Ethnic group: Mixed or Multiple ethnic groups']
census_prep['Pop_White_Total'] = df_census_eth['Ethnic group: White']
census_prep['Pop_Other_Total'] = df_census_eth['Ethnic group: Other ethnic group']

# --- Subgroups (Absolute Totals) ---
census_prep['Pop_Chinese'] = df_census_eth['Ethnic group: Asian, Asian British or Asian Welsh: Chinese']
census_prep['Pop_Asian_Excl_Chinese'] = census_prep['Pop_Asian_Total'] - census_prep['Pop_Chinese']

census_prep['Pop_White_British'] = df_census_eth['Ethnic group: White: English, Welsh, Scottish, Northern Irish or British']
census_prep['Pop_White_Other'] = census_prep['Pop_White_Total'] - census_prep['Pop_White_British'] 

# Initial Merge with Site Sport Data
df_merged = df_site_sport.merge(census_prep, left_on='MSOA code', right_on='MSOA_Code_Join', how='left')

# Weighted Average Function
def weighted_rate(rate1, pop1, rate2, pop2):
    numerator = (rate1 * pop1) + (rate2 * pop2)
    denominator = pop1 + pop2
    return np.where(denominator == 0, 0, numerator / denominator)

# Calculate New Aggregated Rates (active)
df_merged['Active_Asian'] = weighted_rate(
    df_merged['Active_Chinese'], df_merged['Pop_Chinese'],
    df_merged['Active_Asian_(excl._Chinese)'], df_merged['Pop_Asian_Excl_Chinese']
)

df_merged['Active_White'] = weighted_rate(
    df_merged['Active_White_British'], df_merged['Pop_White_British'],
    df_merged['Active_White_Other'], df_merged['Pop_White_Other']
)

df_merged['Active_Other'] = df_merged['Active_Other_ethnic_group']

# Calculate New Aggregated Rates (inactive)
df_merged['Inactive_Asian'] = weighted_rate(
    df_merged['Inactive_Chinese'], df_merged['Pop_Chinese'],
    df_merged['Inactive_Asian_(excl._Chinese)'], df_merged['Pop_Asian_Excl_Chinese']
)

df_merged['Inactive_White'] = weighted_rate(
    df_merged['Inactive_White_British'], df_merged['Pop_White_British'],
    df_merged['Inactive_White_Other'], df_merged['Pop_White_Other']
)

df_merged['Inactive_Other'] = df_merged['Inactive_Other_ethnic_group']

# Calculate Population Percentages (Control Variables)
df_merged['Asian_prop'] = df_merged['Pop_Asian_Total'] / df_merged['Pop_Total']
df_merged['Black_prop'] = df_merged['Pop_Black_Total'] / df_merged['Pop_Total']
df_merged['Mixed_prop'] = df_merged['Pop_Mixed_Total'] / df_merged['Pop_Total']
df_merged['White_prop'] = df_merged['Pop_White_Total'] / df_merged['Pop_Total']
df_merged['Other_prop'] = df_merged['Pop_Other_Total'] / df_merged['Pop_Total']

# Cleanup Columns
cols_to_remove_active = [
    'Active_Asian_(excl._Chinese)', 'Active_Chinese', 
    'Active_White_British', 'Active_White_Other',
    'Active_Black', 'Active_Mixed', 'Active_Other_ethnic_group'
]
cols_to_remove_inactive = [
    'Inactive_Asian_(excl._Chinese)', 'Inactive_Chinese',
    'Inactive_White_British', 'Inactive_White_Other',
    'Inactive_Black', 'Inactive_Mixed', 'Inactive_Other_ethnic_group'
]
cols_to_remove_census_temp = [
    'MSOA_Code_Join', 
    'Pop_Asian_Total', 'Pop_Black_Total', 'Pop_Mixed_Total', 'Pop_White_Total', 'Pop_Other_Total',
    'Pop_Chinese', 'Pop_Asian_Excl_Chinese', 'Pop_White_British', 'Pop_White_Other'
]

all_cols_to_drop = cols_to_remove_active + cols_to_remove_inactive + cols_to_remove_census_temp
df_main_step1 = df_merged.drop(columns=all_cols_to_drop)

# =========================================
# 3. Process Age
# =========================================

# Census Column Definitions
col_15_19 = 'Age: Aged 15 to 19 years'
col_20_24 = 'Age: Aged 20 to 24 years'
col_25_29 = 'Age: Aged 25 to 29 years'
col_30_34 = 'Age: Aged 30 to 34 years'
col_35_39 = 'Age: Aged 35 to 39 years'
col_40_44 = 'Age: Aged 40 to 44 years'
col_45_49 = 'Age: Aged 45 to 49 years'
col_50_54 = 'Age: Aged 50 to 54 years'
col_55_59 = 'Age: Aged 55 to 59 years'
col_60_64 = 'Age: Aged 60 to 64 years'
col_65_69 = 'Age: Aged 65 to 69 years'
col_70_74 = 'Age: Aged 70 to 74 years'
col_75_79 = 'Age: Aged 75 to 79 years'
col_80_84 = 'Age: Aged 80 to 84 years'
col_85_over = 'Age: Aged 85 years and over'

# Calculate Group Counts
# Group 16-34: Take 80% (4/5) of the 15-19 range and sum ranges up to 34 years
count_16_34 = (0.8 * df_census_age[col_15_19]) + \
              df_census_age[col_20_24] + df_census_age[col_25_29] + df_census_age[col_30_34]

# Group 35-54
count_35_54 = df_census_age[col_35_39] + df_census_age[col_40_44] + \
              df_census_age[col_45_49] + df_census_age[col_50_54]

# Group 55-74
count_55_74 = df_census_age[col_55_59] + df_census_age[col_60_64] + \
              df_census_age[col_65_69] + df_census_age[col_70_74]

# Group 75+
count_75_plus = df_census_age[col_75_79] + df_census_age[col_80_84] + df_census_age[col_85_over]

# Total population 16+
total_16_plus = count_16_34 + count_35_54 + count_55_74 + count_75_plus

# Calculate Proportions
df_census_age['Age_16_34_prop'] = count_16_34 / total_16_plus
df_census_age['Age_35_54_prop'] = count_35_54 / total_16_plus
df_census_age['Age_55_74_prop'] = count_55_74 / total_16_plus
df_census_age['Age_75+_prop'] = count_75_plus / total_16_plus

# Select only columns necessary for the merge
census_subset_age = df_census_age[['geography code', 'Age_16_34_prop', 'Age_35_54_prop', 
                                   'Age_55_74_prop', 'Age_75+_prop']]

# Merge Datasets
df_main_step2 = pd.merge(df_main_step1, census_subset_age, 
                         left_on='MSOA code', right_on='geography code', 
                         how='left')

# Remove 'geography code'
df_main_step2 = df_main_step2.drop(columns=['geography code'])

# =========================================
# 4. Process NS-SEC / Job
# =========================================

# Define original column
col_total_ns = "National Statistics Socio-economic Classification (NS-SEC): Total: All usual residents aged 16 years and over"

# Counts for the 7 groups (sums or direct selections)
# Group 1-2: Managerial
count_1_2 = df_census_job["National Statistics Socio-economic Classification (NS-SEC): L1, L2 and L3 Higher managerial, administrative and professional occupations"] + \
            df_census_job["National Statistics Socio-economic Classification (NS-SEC): L4, L5 and L6 Lower managerial, administrative and professional occupations"]

# Group 3: Intermediate
count_3 = df_census_job["National Statistics Socio-economic Classification (NS-SEC): L7 Intermediate occupations"]

# Group 4: Small employers
count_4 = df_census_job["National Statistics Socio-economic Classification (NS-SEC): L8 and L9 Small employers and own account workers"]

# Group 5: Lower supervisory
count_5 = df_census_job["National Statistics Socio-economic Classification (NS-SEC): L10 and L11 Lower supervisory and technical occupations"]

# Group 6-7: Routine
count_6_7 = df_census_job["National Statistics Socio-economic Classification (NS-SEC): L12 Semi-routine occupations"] + \
            df_census_job["National Statistics Socio-economic Classification (NS-SEC): L13 Routine occupations"]

# Group 8: Long-term unemployed / Never worked
count_8 = df_census_job["National Statistics Socio-economic Classification (NS-SEC): L14.1 and L14.2 Never worked and long-term unemployed"]

# Group 9: Students
count_9 = df_census_job["National Statistics Socio-economic Classification (NS-SEC): L15 Full-time students"]

# Total population (16+)
total_pop_ns = df_census_job[col_total_ns]

# Calculating Proportions
df_census_job['NS_1_2_prop'] = count_1_2 / total_pop_ns
df_census_job['NS_3_prop'] = count_3 / total_pop_ns
df_census_job['NS_4_prop'] = count_4 / total_pop_ns
df_census_job['NS_5_prop'] = count_5 / total_pop_ns
df_census_job['NS_6_7_prop'] = count_6_7 / total_pop_ns
df_census_job['NS_8_prop'] = count_8 / total_pop_ns
df_census_job['NS_9_prop'] = count_9 / total_pop_ns

cols_to_merge_ns = ['geography code', 'NS_1_2_prop', 'NS_3_prop', 'NS_4_prop', 
                    'NS_5_prop', 'NS_6_7_prop', 'NS_8_prop', 'NS_9_prop']

# Renaming columns in Main Dataset (Active/Inactive NS-SEC)
rename_dict = {
    'Active_NS_SEC_1_2_managerial_administrative_and_professional_occupations': 'Active_NS_1_2',
    'Active_NS_SEC_3_intermediate_occupations': 'Active_NS_3',
    'Active_NS_SEC_4_self_employed_and_small_employers': 'Active_NS_4',
    'Active_NS_SEC_5_lower_supervisory_and_technical_occupations': 'Active_NS_5',
    'Active_NS_SEC_6_7_semi_routine_and_routine_occupations': 'Active_NS_6_7',
    'Active_NS_SEC_8_long_term_unemployed_or_never_worked': 'Active_NS_8',
    'Active_NS_SEC_9_students': 'Active_NS_9',
    
    'Inactive_NS_SEC_1_2_managerial_administrative_and_professional_occupations': 'Inactive_NS_1_2',
    'Inactive_NS_SEC_3_intermediate_occupations': 'Inactive_NS_3',
    'Inactive_NS_SEC_4_self_employed_and_small_employers': 'Inactive_NS_4',
    'Inactive_NS_SEC_5_lower_supervisory_and_technical_occupations': 'Inactive_NS_5',
    'Inactive_NS_SEC_6_7_semi_routine_and_routine_occupations': 'Inactive_NS_6_7',
    'Inactive_NS_SEC_8_long_term_unemployed_or_never_worked': 'Inactive_NS_8',
    'Inactive_NS_SEC_9_students': 'Inactive_NS_9'
}

df_main_step2 = df_main_step2.rename(columns=rename_dict)

# Merging Datasets (Merging Step 2 Result with NS-SEC Data)
final_df = pd.merge(df_main_step2, df_census_job[cols_to_merge_ns], 
                    left_on='MSOA code', right_on='geography code', 
                    how='left')

# Remove duplicate column
final_df = final_df.drop(columns=['geography code'])

# =========================================
# 5. Save Final Output
# =========================================

output_filename = 'datasets/final_ds.csv'
final_df.to_csv(output_filename, index=False)

print(f"Process completed. File saved to: {output_filename}")