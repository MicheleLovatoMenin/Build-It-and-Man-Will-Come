import pandas as pd

df_fac = pd.read_csv('datasets/facilities/facilities.csv')

# Aggregation by Site ID
df_sites = df_fac.groupby('Site ID').agg({
    'Latitude': 'first',
    'Longitude': 'first',
    'Facility Type': [
        'count',                      
        'nunique',                    
        lambda x: ', '.join(map(str, sorted(x)))
    ],
    'Facility Subtype': 'nunique'     
}).reset_index()

# Columns
df_sites.columns = ['Site_ID', 'Lat', 'Lon', 'Total_Facilities', 'Diversity_Index', 'Facility_Types_List', 'Subtype_Diversity']

# Save
print(df_sites.head())
df_sites.to_csv('datasets/site_fac.csv', index=False)
print("File saved!")