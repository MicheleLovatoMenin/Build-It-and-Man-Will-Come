import geopandas as gpd
import pandas as pd

# Utils functiones
def get_unique_types_count(series_of_lists_str):
    unique_types = set()
    for item in series_of_lists_str:
        if pd.notna(item) and item != '':
            codes = [x.strip() for x in str(item).split(',')]
            unique_types.update(codes)
    unique_types.discard('') 
    return len(unique_types)

def get_unique_types_list(series_of_lists_str):
    unique_types = set()
    for item in series_of_lists_str:
        if pd.notna(item) and item != '':
            codes = [x.strip() for x in str(item).split(',')]
            unique_types.update(codes)
    unique_types.discard('')
    return ', '.join(sorted(unique_types, key=lambda x: int(x) if x.isdigit() else 999))

def count_no_football(type_list_str):
    if pd.isna(type_list_str) or type_list_str == '':
        return 0
    codes = [x.strip() for x in str(type_list_str).split(',')]
    return len([c for c in codes if c != '5'])

# Data Loading
df_sites = pd.read_csv('datasets/site_fac.csv')

df_sites['Facilities_No_Football'] = df_sites['Facility_Types_List'].apply(count_no_football)

# GeoDataFrame Sites
gdf_sites = gpd.GeoDataFrame(
    df_sites, 
    geometry=gpd.points_from_xy(df_sites.Lon, df_sites.Lat),
    crs="EPSG:4326"
)

shapefile_name = "datasets/middle_layer/MSOA_2021_EW_BGC_V3.shp" 
gdf_msoa = gpd.read_file(shapefile_name)

# Proiezione Metrica (British National Grid)
gdf_sites = gdf_sites.to_crs("EPSG:27700")
gdf_msoa = gdf_msoa.to_crs("EPSG:27700")

# 
# INTERNAL DENSITY CALCULATION (Inside MSOA Boundaries)
print("Interal density calculation..")
join_inside = gpd.sjoin(gdf_sites, gdf_msoa, how="inner", predicate="within")

stats_inside = join_inside.groupby('MSOA21CD').agg({
    'Site_ID': 'count',
    'Total_Facilities': 'sum',
    'Facilities_No_Football': 'sum',
    'Facility_Types_List': [get_unique_types_count, get_unique_types_list]
})
stats_inside.columns = ['Sites_Inside', 'Facilities_Inside', 'Facilities_Inside_No_Football', 'Diversity_Index_Inside', 'Type_List_Inside']


# Nearest distance calculation
print("Nearest distance calculation...")
gdf_centroids = gdf_msoa.copy()
gdf_centroids.geometry = gdf_centroids.geometry.centroid 
nearest = gpd.sjoin_nearest(gdf_centroids, gdf_sites, distance_col="Dist_Nearest_m")
dist_stats = nearest[['MSOA21CD', 'Dist_Nearest_m']].drop_duplicates(subset='MSOA21CD')

# Final union
final_df = pd.DataFrame(gdf_msoa[['MSOA21CD', 'MSOA21NM']]) 

# Merging
dfs_to_merge = [stats_inside, dist_stats] 
for df in dfs_to_merge:
    final_df = final_df.merge(df, on='MSOA21CD', how='left')

# NaN Handling
num_cols = ['Sites_Inside', 'Facilities_Inside', 'Facilities_Inside_No_Football', 'Diversity_Index_Inside']
final_df[num_cols] = final_df[num_cols].fillna(0)

str_cols = [c for c in final_df.columns if 'Type_List' in c]
final_df[str_cols] = final_df[str_cols].fillna('')

# Saving
output_name = 'datasets/site_msoa.csv'
final_df.to_csv(output_name, index=False)
print(f"Finish! File '{output_name}' saved.")
print(final_df[['MSOA21NM', 'Sites_Inside', 'Facilities_Inside', 'Diversity_Index_Inside', 'Type_List_Inside']].head())