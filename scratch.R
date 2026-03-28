# Scratch code playing around --------------------------------------------

# Read in and process data with rredlist ---------------------------------
# https://docs.ropensci.org/rredlist/

library(rredlist)
library(tidyverse)
rl_family()
# chordata <- rl_phylum(phylum = "Chordata")

categories <- rl_categories()
catcodes <-
  categories$red_list_categories$code |>
  grepv("^[A-Z]{2}$", x = _) |>
  unique() |>
  sort()

system.time({
  dl <- lapply(catcodes, rl_categories)
  saveRDS(dl, file = "redlist_raw.rds")
})

catcodes_reduced <- c("LC", "NT", "VU", "EN", "CR", "RE", "EW", "EX")

d <-
  dl |>
  map("assessments") |>
  bind_rows() |>
  as_tibble() |>
  select(
    year = year_published,
    latest,
    taxid = sis_taxon_id,
    species = taxon_scientific_name,
    code,
    scopes
  ) |>
  mutate(scope = map(scopes, \(x) x[[1]]$en), .keep = "unused") |>
  unnest_longer(scope) |>
  select(year, latest, scope, taxid, species, code, everything()) |>
  distinct() |>
  arrange(desc(year), scope, taxid, code) |>
  filter(code %in% catcodes_reduced) |>
  mutate(code = factor(code, levels = catcodes_reduced))

saveRDS(d, file = "redlist.rds")
d |> nanoparquet::write_parquet("redlist.parquet")


# explore ----------------------------------------------------------------

d <- nanoparquet::read_parquet("redlist.parquet")

d |>
  count(code) |>
  ggplot(aes(code, n)) +
  geom_col()

# Join to taxonomy
# Something here...

# Read in and explore with iucnredlist -----------------------------------
# https://github.com/iucn-uk/iucnredlist

# devtools::install_github("IUCN-UK/iucnredlist")

library(iucnredlist)
api <- init_api("KPM47GxUt7Lrn4ofGrBSUEVhZBW7wyRvYqvK")
assessment_raw <- assessment_data(api, 266696959)
assessment_raw
assessment <- parse_assessment_data(assessment_raw)

sturgeon <- assessments_by_sis_id(api, 230)
sturgeon
