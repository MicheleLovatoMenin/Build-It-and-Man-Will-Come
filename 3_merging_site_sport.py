import pandas as pd

# Files configuration
excel_file = 'datasets/Small area estimates - adult MSOA and LSOA 23-24.xlsx'
spatial_file = 'datasets/site_msoa.csv'

# Columns
cols_to_keep = [
    'MSOA code', 'MSOA name', 
    'All adults', 
    'Female', 'Male',          
    'NS SEC 1-2: managerial, administrative and professional occupations',
    'NS SEC 3: intermediate occupations',
    'NS SEC 4: self employed and small employers',
    'NS SEC 5: lower supervisory and technical occupations',
    'NS SEC 6-7: semi-routine and routine occupations',
    'NS SEC 8: long term unemployed or never worked',
    'NS SEC 9: students',
    'Aged 16-34', 'Aged 35-54', 'Aged 55-74', 'Aged 75+',
    'Asian (excl. Chinese)', 'Black', 'Chinese', 'Mixed', 
    'Other ethnic group', 'White British', 'White Other'
]

# Header
def load_sheet_smart(file_path, sheet_name, keyword='MSOA code'):
    print(f"Trying to find the header for sheet '{sheet_name}'...")
    df_temp = pd.read_excel(file_path, sheet_name=sheet_name, header=None, nrows=10)
    header_row = 0
    found = False
    
    for i, row in df_temp.iterrows():
        if row.astype(str).str.contains(keyword).any():
            header_row = i
            found = True
            print(f" -> Header found in the raw {i}")
            break
    
    if not found:
        print(f"ATTENTION: Keyword '{keyword}' non found in the first 10 rows. I will try with header=0.")
    
    return pd.read_excel(file_path, sheet_name=sheet_name, header=header_row)

# Data Loading
print("Excel data loading...")
df_active = load_sheet_smart(excel_file, 'Active MSOA')
df_inactive = load_sheet_smart(excel_file, 'Inactive MSOA')

print("Spatial data loading...")
df_spatial = pd.read_csv(spatial_file)

# Data cleaning
def clean_dataset(df, prefix):
    available_cols = [c for c in cols_to_keep if c in df.columns]
    
    # DEBUG
    if 'MSOA code' not in available_cols:
        print(f"ERROR in {prefix}: Colomn 'MSOA code' not found!")
        print("Available Columns:", df.columns.tolist())
        raise KeyError(f"There is'nt 'MSOA code' in sheet {prefix}")

    df_subset = df[available_cols].copy()
    
    rename_dict = {}
    for col in df_subset.columns:
        if col not in ['MSOA code', 'MSOA name']:
            clean_col = col.replace(':', '').replace(',', '').replace(' ', '_').replace('-', '_')
            rename_dict[col] = f"{prefix}_{clean_col}"
            
    return df_subset.rename(columns=rename_dict)

print("Cleaning dataset...")
df_act_clean = clean_dataset(df_active, "Active")
df_inact_clean = clean_dataset(df_inactive, "Inactive")

# Merging
print("Merging datasets...")

master_df = df_act_clean.merge(
    df_inact_clean.drop(columns=['MSOA name'], errors='ignore'), 
    on='MSOA code', 
    how='left'
)

master_df = master_df.merge(
    df_spatial,
    left_on='MSOA code', 
    right_on='MSOA21CD', 
    how='left'
)

# Gender gap
master_df['Gender_Gap_Active'] = master_df['Active_Male'] - master_df['Active_Female']
master_df['Gender_Gap_Inactive'] = master_df['Inactive_Male'] - master_df['Inactive_Female']

# Final Cleaning
cols_to_drop = ['MSOA21CD', 'MSOA21NM'] 
master_df = master_df.drop(columns=[c for c in cols_to_drop if c in master_df.columns], errors='ignore')

# Saving
output_file = 'datasets/site_sport.csv'
master_df.to_csv(output_file, index=False)
print(f"------------------------------------------------")
print(f"File created: {output_file}")
print(f"Total number of rows: {len(master_df)}")