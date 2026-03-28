# IUCN Red List Category Transitions

## Project goal

Quantify how often species move between IUCN Red List categories over time, with a focus on downlisting (moves from higher-threat to lower-threat categories, e.g. Endangered to Vulnerable). Summarize transition rates by taxonomic group (birds, mammals, amphibians, reptiles, fishes, invertebrates, plants).

## Key context

### Category ordinal scale (most threatened to least)

EX (Extinct) > EW (Extinct in the Wild) > CR (Critically Endangered) > EN (Endangered) > VU (Vulnerable) > NT (Near Threatened) > LC (Least Concern)

DD (Data Deficient) is not part of the threat hierarchy. Transitions involving DD should be tracked separately and excluded from directional analyses.

### Genuine vs. non-genuine changes

This is the single most important methodological issue. Many category changes result from new data, revised taxonomy, or corrected errors rather than actual population change. The IUCN records a "reason for change" with each reassessment. Only transitions coded as "Genuine (recent)" or "Genuine (since first assessment)" reflect real population improvement or deterioration. Non-genuine changes (new/better data, taxonomy revision, criteria revision, incorrect data, etc.) must be filtered out or clearly separated.

### Pre-2001 category mapping

Before the 2001 criteria revision (v3.1), the IUCN used different category names. Rough mappings: Endangered (old) ~ EN, Vulnerable (old) ~ VU, Rare ~ VU, Indeterminate ~ unresolvable, Insufficiently Known ~ DD. Be cautious with pre-2001 assessments. Consider restricting primary analyses to post-2001 assessments and treating pre-2001 data as supplementary.

### Prior work

A July 2025 paper in Conservation Biology (Yong et al.) analyzed 1,511 species with genuine category changes from 1988-2024 and found roughly 1 in 1,000 assessed species have been downlisted due to genuine improvement. That paper uses Sankey/alluvial diagrams for visualization. Any analysis here should be positioned relative to that work.

## Technical approach

### Language and tools

- R (primary language)
- `rredlist` package (ropensci, CRAN) for IUCN Red List API v4
- `tidyverse` for data wrangling
- `ggplot2` + `ggalluvial` or `networkD3` for Sankey/alluvial visualizations
- API key stored as environment variable `IUCN_REDLIST_KEY`

### Data acquisition strategy

**Preferred: IUCN bulk download.** Before writing extensive API-scraping code, check whether the IUCN Red List bulk download (requires registration at iucnredlist.org) provides assessment history with category-change reasons in flat files. This is far more practical for comprehensive all-taxa analysis than making tens of thousands of individual API calls.

**Fallback: API via rredlist.** If bulk data doesn't include what we need, use the API with these considerations:

- `rl_class()`, `rl_order()`, `rl_family()`: get assessment lists by taxonomic group (paginated)
- `rl_species("Genus", "species")` or `rl_sis(sis_id)`: get all historical assessments for a species
- `rl_assessment(id)`: get full assessment detail including `red_list_category`
- `rl_assessment_extract(assessments, "red_list_category")`: batch-extract categories from assessment lists
- `rl_scopes()`: filter to global-scope assessments only
- Rate limit: 2-second delay between calls. Wrap API calls with `Sys.sleep(2)` and incremental caching.
- Cache all API responses locally (RDS or parquet) so nothing gets re-downloaded on subsequent runs.
- Write resumable scripts that save progress and can restart from where they left off.

### Target taxonomic groups

Primary (best reassessment coverage): AVES, MAMMALIA, AMPHIBIA
Secondary: REPTILIA, ACTINOPTERYGII (ray-finned fishes)
Tertiary (patchy coverage, interpret cautiously): invertebrate classes, plant groups

### rredlist key functions reference

```r
# Setup
rl_use_iucn()                          # Interactive API key setup
rl_api_version()                       # Check API connectivity
rl_citation()                          # Get proper citation text

# Species lookups
rl_species("Genus", "species")         # All assessments for a species
rl_sis(sis_id)                         # All assessments by SIS taxon ID
rl_species_latest("Genus", "species")  # Latest assessment only
rl_sis_latest(sis_id)                  # Latest assessment by SIS ID

# Taxonomic group queries (paginated, use page = NA for all)
rl_class(name)                         # Assessments by class
rl_order(name)                         # Assessments by order
rl_family(name)                        # Assessments by family
rl_kingdom(name)                       # Assessments by kingdom

# Assessment details
rl_assessment(id)                      # Full detail for one assessment
rl_assessment_list(ids)                # Full detail for multiple assessments
rl_assessment_extract(data, el_name)   # Extract element from assessment list
# el_name options: "taxon", "red_list_category", "habitats", "threats", etc.

# Filtering/scoping
rl_scopes()                            # List assessment scopes (Global, etc.)
rl_categories()                        # List all Red List categories
```

## Project structure

```
project-root/
├── CLAUDE.md              # This file
├── R/
│   ├── 01_fetch_species.R       # Download species lists by taxonomic group
│   ├── 02_fetch_assessments.R   # Get historical assessments per species
│   ├── 03_extract_categories.R  # Pull categories from assessment details
│   ├── 04_build_transitions.R   # Compute consecutive-assessment pairs
│   ├── 05_filter_genuine.R      # Filter for genuine changes
│   ├── 06_summarize.R           # Aggregate by taxonomic group
│   └── utils.R                  # Caching, rate-limiting, helpers
├── data/
│   ├── raw/                     # Cached API responses (gitignored)
│   ├── processed/               # Clean intermediate datasets
│   └── bulk/                    # IUCN bulk download files if used
├── output/
│   ├── figures/
│   └── tables/
├── .env                         # IUCN_REDLIST_KEY (gitignored)
└── .gitignore
```

## Analysis pipeline

1. **Fetch species lists** by class/order. Build master table: sis_taxon_id, scientific_name, kingdom, phylum, class, order, family, genus, species.
2. **Fetch all assessments** per species. Output: (sis_taxon_id, assessment_id, year_published, scope).
3. **Get assessment details**. Extract red_list_category and (if available) reason-for-change for each assessment.
4. **Build transition pairs**. For each species, sort assessments chronologically. Create rows of (species, category_from, category_to, year_from, year_to, direction). Direction: "downlisted" if moving toward LC, "uplisted" if moving toward EX, "stable" if same category.
5. **Filter genuine changes**. Keep only transitions where the reason is coded as genuine. If reason metadata is unavailable from API, cross-reference with IUCN summary statistics spreadsheets.
6. **Summarize**. Counts and rates of downlisting/uplisting by class, order, time period. Sankey/alluvial diagrams. Proportion of species ever downlisted. Mean category-step size of transitions.

## Coding conventions

- Use tidyverse style throughout.
- Every script should be runnable independently given cached data from prior steps.
- Print progress messages for long-running API fetches (species count, estimated time remaining).
- All API-fetched data cached to `data/raw/` as RDS files keyed by taxonomic group or species ID.
- Use `cli` or `message()` for status output, not `print()`.
- Comment the "why," not the "what."

## Important caveats to track

- Some species have been split or lumped taxonomically between assessments. Transitions across taxonomic revisions are not meaningful and should be flagged.
- Subpopulation assessments exist alongside species-level assessments. Filter to species-level only (check `subpopulation` field).
- The IUCN recommends reassessment every 5-10 years, but actual intervals vary widely. Report assessment intervals alongside transition rates.
- "Possibly extinct" species within CR should be noted but are still categorized as CR in the formal system.