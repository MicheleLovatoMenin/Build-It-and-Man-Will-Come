# Build It and Men Will Come: A Spatial Analysis of Sports Infrastructure and the Gender Play Gap in England

> **Note:** The full academic paper associated with this repository is available as a PDF file in the root directory. Please refer to it for the complete methodology, theoretical framework, and author details.

## 📄 Abstract & Key Findings

This study challenges the prevailing supply-side narrative in sports policy: "Build it and they will come" by investigating whether the built environment acts as a catalyst for physical activity or merely reflects existing inequalities. Focusing on the entire territory of England ($N=6,856$ MSOAs), we employ a **Spatial Durbin Error Model (SDEM)** to disentangle the impact of sports infrastructure from socio-economic sorting.

**Key Findings:**
* **The Local Fallacy:** Once structural controls such as wealth and age are accounted for, the mere density of facilities shows no significant impact on participation rates.
* **Inequality Multiplier:** The current infrastructure stock acts as an "Inequality Multiplier" regarding the Gender Play Gap. A higher density of facilities is associated with a widening of the gender divide, disproportionately benefiting men.
* **Diversity Paradox:** While a higher Diversity Index of sports provision attracts more male participants, female participation remains largely inelastic to supply changes.

## 🛠️ Installation

### 1. Python Dependencies (Data Processing & Visualization)
The Python environment is used for the data cleaning pipeline and generating the interactive HTML maps.
To install the required libraries:

```bash
pip install -r requirements.txt
```

### 2. R Dependencies (Statistical Analysis)
The R environment is used for the Descriptive Analysis and the Spatial Econometrics Models (SDEM).
A script is provided to automatically check and install the necessary packages: `install_packages.R`.

## 📂 Data Pipeline

The raw datasets are located in the `/dataset` folder. However, for transparency and reproducibility, here are the links to the official sources:

* **Sports Facilities:** Sourced from the [Active Places Power](https://www.activeplacespower.com/pages/downloads) database (Sport England).
* **Physical Activity:** Sourced from the [Active Lives Survey](https://www.sportengland.org/research-and-data/data/active-lives) (Sport England).
* **Census Data:** Socio-economic status (NS-SEC), Ethnicity, and Age structure sourced from the [2021 Census](https://www.ons.gov.uk/census) (ONS - Office for National Statistics).

### Step 1: Data Cleaning & Merging (Python)
Run the scripts in the following order to reproduce the final dataset:

1. **`1_data_cleaning_fac.py`**:
    * *Input:* `facilities.csv`
    * *Output:* `site_fac.csv` (Aggregaes facilities by sites).
2. **`2_data_cleaning_msoa.py`**:
    * *Input:* `site_fac.csv`
    * *Output:* `site_msoa.csv` (Aggregates sites by MSOA).
3. **`3_merging_site_sport.py`**:
    * *Input:* `site_msoa.csv`, `Small area estimates - adult MSOA and LSOA 23-24.xlsx`
    * *Output:* `site_sport.csv` (Merges infrastructure with participation data).
4. **`4_merging_etn_age_job.py`**:
    * *Input:* `site_sport.csv`, `census_ethnic_msoa.csv`, `census_age_msoa.csv`, `census_job_msoa.csv`
    * *Output:* **`final_ds`** (The final dataset used for analysis).

### Step 2: Statistical Analysis (R)
* **`Descriptive Analysis.R`**: Generates summary statistics and preliminary plots.
* **`Geospatial Analysis.R`**: Runs the Spatial Durbin Error Models (SDEM).
    * *Note:* Since spatial models are computationally intensive, the trained models are saved as `.rds` files in the `/output_models` directory. You can load them directly to inspect results without re-running the training process.

## 🗺️ Interactive Maps & Visualization

The core visualization tool is the Jupyter Notebook **`interactive_map.ipynb`**. This notebook generates high-detail interactive HTML maps for the entire UK territory.

### 1. The Interactive Atlas
The notebook produces two main map files:
* **`Physical_Activity_Map.HTML`**
* **`Sociodemographic_Map.HTML`**

> **⚠️ Download Note:** Due to the high level of detail, these maps cannot be hosted directly on GitHub.
> You can generate them locally by running the notebook, or download the pre-generated HTML files [here](https://drive.google.com/drive/u/0/folders/11xuF48L5iZXWUP08hplKYtS6WMPeO8dn?q=sharedwith:public%20parent:11xuF48L5iZXWUP08hplKYtS6WMPeO8dn).

**How to use the maps:**
* **Layer Control:** Use the layer selector to toggle variables (e.g., *Active Adults*, *Inactive Adults*, *Gender Gap*). **Important:** Always deselect the current layer before selecting a new one to avoid visual overlap.
* **Data Inspection:** Hover over any MSOA to see a popup with specific metrics (Zone ID, Number of Facilities, Diversity Index, Participation Rates).
* **Facility Zoom:** If you zoom in deeply, the **"Sport Site Locations"** layer will reveal individual sport sites. Clicking on a marker shows exactly which facilities are inside (e.g., "Gym", "Pool", "Tennis Court").

### 2. Isochrone Analysis (Walkability)
The notebook also performs a walkability analysis:
* It calculates 10, 20, and 30-minute walking isochrones from the centroid of selected MSOAs.
* It computes how many sport sites and facilities are accessible within those timeframes.
* **Customization:** The notebook is set to analyze 5 sample MSOAs by default, but you can change the MSOA Codes in the script to generate isochrones for any neighborhood in England.
* **Output:** Files are saved in `/maps_output` as `isochrone_map_[MSOA_CODE].html`.
