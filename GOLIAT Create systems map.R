# Title: Creating a systems  map in R for upload to a GitHub Pages site
# Author: James Grellier
# Date created: 20260615
# Date last edited: 20260702

# Load packages
if (!require("pacman")) install.packages("pacman") # Installs the pacman package, which allows for tidy package management
pacman::p_load(htmltools,
               htmlwidgets,
               readxl,
               tidyverse,
               visNetwork)   # Checks if listed packages are already installed, and installs them if not

# Clean up workspace
rm(list = ls())

# Set working directory
setwd("c:/Users/jg548/OneDrive - University of Exeter/GOLiAT/09 Tasks/T6.1/")

# Read Kumu export 
elements_raw <- read_excel("20260616 GOLIATmap.xlsx", sheet = "Elements")
connections_raw <- read_excel("20260616 GOLIATmap.xlsx", sheet = "Connections")

# Inspect column names 
names(elements_raw)
names(connections_raw)

# Inspect data
summary(connections_raw)
dim(connections_raw)
names(connections_raw)
names(elements_raw)

# Inspect categories
elements_raw %>%
  mutate(Category = as.factor(Category),
         Type = as.factor(Type)) %>%
  select(Category, Type) %>%
  unique() %>%
  print(n = Inf)

elements_raw %>%
  mutate(Category = as.factor(Category)) %>%
  summary()

connections_raw %>%
  mutate(Relationship = as.factor(Relationship)) %>%
  select(Relationship) %>%
  summary()

# Create broad categories
elements_for_layout <- elements_raw %>%
  mutate(
    broad_type = if_else(Type == "Exposure", "Exposure", "Outcome")
  )

# Attempt to create coordinates for each node
grand_radius <- 4000
category_radius <- 500

## Place each Category centre around the grand circle -------------------
category_positions <- elements_for_layout %>%
  distinct(Category, broad_type) %>%
  group_by(broad_type) %>%
  arrange(Category, .by_group = TRUE) %>%
  mutate(
    category_id = row_number(),
    n_categories = n(),
    grand_angle = case_when(
      broad_type == "Exposure" ~ pi * category_id / (n_categories + 1),
      broad_type == "Outcome"  ~ pi + pi * category_id / (n_categories + 1)
    ),
    category_x = grand_radius * cos(grand_angle),
    category_y = -grand_radius * sin(grand_angle)
  ) %>%
  ungroup()

## Position nodes around each category centre
nodes_with_coords <- elements_for_layout %>%
  left_join(category_positions, by = c("Category", "broad_type")) %>%
  group_by(Category, broad_type) %>%
  arrange(Label, .by_group = TRUE) %>%
  mutate(
    node_id_in_category = row_number(),
    n_nodes_in_category = n(),
    node_angle = 2 * pi * (node_id_in_category - 1) / n_nodes_in_category,
    x = category_x + category_radius * cos(node_angle),
    y = category_y + category_radius * sin(node_angle),
    id = Label,
    label = Label,
    group = Category
  ) %>%
  ungroup()

# Create reference blocks with DOI link
make_reference_blocks <- function(refs) {
  
  refs <- refs[!is.na(refs) & refs != ""]
  refs <- unique(refs)
  
  refs <- stringr::str_replace_all(
    refs,
    "(https://doi\\.org/[A-Za-z0-9./_()\\-]+)",
    "<a href='\\1' target='_blank'>\\1</a>"
  )
  
  paste0("<p>", refs, "</p>") %>%
    paste(collapse = "")
}

edges_collapsed <- connections_raw %>%
  group_by(From, To, Relationship) %>%
  summarise(
    n_references = n_distinct(Reference),
    
    Themes = paste(
      sort(unique(Theme[!is.na(Theme) & Theme != ""])),
      collapse = "|"
    ),
    
    references_html = make_reference_blocks(Reference),
    
    .groups = "drop"
  ) %>%
  mutate(
    id = row_number(),
    from = From,
    to = To,
    label = Relationship,
    arrows = "to",
    
    value = n_references,
    width = 1 + log1p(n_references),
    
    color = case_when(
      Relationship == "Positive impact" ~ "darkgreen",
      Relationship == "Negative impact" ~ "darkred",
      TRUE ~ "grey50"
    ),
    
    Theme_A = str_detect(Themes, "(^|\\|)A($|\\|)"),
    Theme_B = str_detect(Themes, "(^|\\|)B($|\\|)"),
    Theme_C = str_detect(Themes, "(^|\\|)C($|\\|)"),
    Theme_D = str_detect(Themes, "(^|\\|)D($|\\|)"),
    Theme_E = str_detect(Themes, "(^|\\|)E($|\\|)"),
    Theme_F = str_detect(Themes, "(^|\\|)F($|\\|)"),
    
    title = paste0(
      "<b>", from, " → ", to, "</b><br>",
      "<b>Relationship:</b> ", Relationship, "<br>",
      "<b>Themes:</b> ", Themes, "<br>",
      "<b>References:</b> ", n_references, "<br>",
      "Click edge for full details."
    ),
    
    details_html = paste0(
      "<h3>", from, " → ", to, "</h3>",
      "<p><b>Relationship:</b> ", Relationship, "</p>",
      "<p><b>Themes:</b> ", Themes, "</p>",
      "<p><b>Number of references:</b> ", n_references, "</p>",
      "<h4>References</h4>",
      references_html
    )
  )

edges_E <- edges_collapsed %>%
  filter(Theme_E)

connections_raw %>%
  distinct(From, To, Relationship, Theme) %>%
  count(From, To, Relationship) %>%
  filter(n > 1)

connections_raw %>%
  filter(From == "Excessive gaming" & To == "Negative psychological outcomes") %>%
  select(ID, Reference, Theme)

# Calculate node degree
node_degree <- edges_collapsed %>%
  select(from, to) %>%
  tidyr::pivot_longer(
    cols = c(from, to),
    values_to = "id"
  ) %>%
  count(id, name = "degree")

# Size by degree
nodes_with_coords_sized <- nodes_with_coords %>%
  select(-any_of(c("degree", "size"))) %>%
  left_join(node_degree, by = "id") %>%
  mutate(
    degree = tidyr::replace_na(degree, 0),
    size = 20 + 5 * degree
  )

nodes_with_coords_sized %>% # Inspect sizing range
  summarise(
    min_degree = min(degree),
    max_degree = max(degree),
    min_size = min(size),
    max_size = max(size)
  )

# Add Category labels
category_label_nodes <- nodes_with_coords_sized %>%
  group_by(Category) %>%
  summarise(
    x = mean(x, na.rm = TRUE),
    y = mean(y, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    id = paste0("CATEGORY_LABEL_", Category),
    label = str_wrap(Category, width = 12),
    group = "Category label",
    shape = "text",
    size = 30,
    font.size = 150,
    font.face = "Arial",
    physics = FALSE,
    title = paste0("<b>", Category, "</b>")
  )

nodes_with_category_labels <- bind_rows(
  nodes_with_coords_sized,
  category_label_nodes
)

# Create category levels (so as not to get colour changes etc. when filtering later on)
category_levels <- sort(unique(nodes_with_category_labels$group))

category_colours <- setNames(
  grDevices::hcl.colors(length(category_levels), "Dark 3"),
  category_levels
)

# Create map
goliat_map_all <- visNetwork(
  nodes_with_category_labels,
  edges_collapsed,
  width = "100%",
  height = "900px"
) %>%
  visGroups(
    groupname = category_levels[1],
    color = category_colours[[category_levels[1]]]
  ) %>%
  visNodes(
    shape = "dot",
    font = list(size = 30)
  ) %>%
  visEdges(
    smooth = list(
      enabled = TRUE,
      type = "curvedCW",
      roundness = 0.2
    ),
    font = list(size = 10, align = "middle"),
    color = list(inherit = FALSE)
  ) %>%
  visOptions(
    highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
    nodesIdSelection = FALSE,
    ) %>%
  visInteraction(
    navigationButtons = TRUE,
    keyboard = TRUE,
    hover = TRUE,
    dragNodes = TRUE
  ) %>%
  visPhysics(enabled = FALSE) %>%
  visEvents(
    selectEdge = "
      function(params) {
        if (params.edges.length > 0) {
          var edgeId = params.edges[0];
          var edge = this.body.data.edges.get(edgeId);
          document.getElementById('edge-details').innerHTML = edge.details_html;
        }
      }
    "
  )

goliat_map_all

# Create legend
relationship_legend <- tags$div(
  style = paste(
    "padding:10px;",
    "border-bottom:1px solid #ccc;",
    "font-family:Arial;",
    "font-size:14px;"
  ),
  tags$b("Edge legend: "),
  tags$span(
    style = "display:inline-block; width:30px; height:4px; background:darkgreen; margin:0 6px 3px 12px;"
  ),
  "Positive impact",
  tags$span(
    style = "display:inline-block; width:30px; height:4px; background:darkred; margin:0 6px 3px 18px;"
  ),
  "Negative impact"
)

# Create navigation bar
navigation_bar <- tags$div(
  style = paste(
    "padding:10px;",
    "background:#f5f5f5;",
    "border-bottom:1px solid #ccc;",
    "font-family:Arial;"
  ),
  
  tags$a(
    href = "index.html",
    target = "_top",
    "🏠 Return to map index",
    style = paste(
      "font-weight:bold;",
      "text-decoration:none;"
    )
  )
)

# Create browsable version with side bar and legend included
goliat_map_all_with_panel <- browsable(
  tagList(
    navigation_bar,
    relationship_legend,
    tags$div(
      style = "display:flex; width:100%;",
      
      tags$div(
        style = "width:75%;",
        goliat_map_all
      ),
      
      tags$div(
        id = "edge-details",
        style = paste(
          "width:25%;",
          "height:900px;",
          "overflow-y:auto;",
          "padding:15px;",
          "border-left:1px solid #ccc;",
          "font-family:Arial;",
          "font-size:14px;"
        ),
        HTML("<h3>Edge details</h3><p>Click a connection to see references and DOIs.</p>")
      )
    )
  )
)

goliat_map_all_with_panel

# Save output
save_html(
  goliat_map_all_with_panel,
  file = "GOLIAT_Theme_All_with_panel.html"
)

# Create browsable version, exploded one edge per reference, with side bar and legend included
# All relationships, exploded by reference

edges_all_exploded <- connections_raw %>%
  group_by(From, To) %>%
  mutate(
    n_parallel_edges = n(),
    edge_number = row_number(),
    curvature_value = if (n() == 1) {
      0.2
    } else {
      seq(0.05, 0.45, length.out = n())[edge_number]
    }
  ) %>%
  ungroup() %>%
  mutate(
    id = row_number(),
    from = From,
    to = To,
    label = Relationship,
    arrows = "to",
    width = 1.5,
    
    color = case_when(
      Relationship == "Positive impact" ~ "darkgreen",
      Relationship == "Negative impact" ~ "darkred",
      TRUE ~ "grey50"
    ),
    
    smooth = purrr::map(
      curvature_value,
      ~list(
        enabled = TRUE,
        type = "curvedCW",
        roundness = .x
      )
    ),
    
    title = paste0(
      "<b>", from, " → ", to, "</b><br>",
      "<b>Relationship:</b> ", Relationship, "<br>",
      "<b>Theme:</b> ", Theme, "<br>",
      "Click edge for full details."
    )
  ) %>%
  rowwise() %>%
  mutate(
    details_html = paste0(
      "<h3>", from, " → ", to, "</h3>",
      "<p><b>Relationship:</b> ", Relationship, "</p>",
      "<p><b>Theme:</b> ", Theme, "</p>",
      "<h4>Reference</h4>",
      make_reference_blocks(Reference)
    )
  ) %>%
  ungroup()

goliat_map_all_exploded <- visNetwork(
  nodes_with_category_labels,
  edges_all_exploded,
  width = "100%",
  height = "900px"
) %>%
  visNodes(
    shape = "dot",
    font = list(size = 30)
  ) %>%
  visEdges(
    font = list(size = 10, align = "middle"),
    color = list(inherit = FALSE)
  ) %>%
  visOptions(
    highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
    nodesIdSelection = FALSE
  ) %>%
  visInteraction(
    navigationButtons = TRUE,
    keyboard = TRUE,
    hover = TRUE,
    dragNodes = TRUE
  ) %>%
  visPhysics(enabled = FALSE) %>%
  visEvents(
    selectEdge = "
      function(params) {
        if (params.edges.length > 0) {
          var edgeId = params.edges[0];
          var edge = this.body.data.edges.get(edgeId);
          document.getElementById('edge-details').innerHTML = edge.details_html;
        }
      }
    "
  )

goliat_map_all_exploded_with_panel <- browsable(
  tagList(
    navigation_bar,
    relationship_legend,
    tags$div(
      style = "display:flex; width:100%;",
      
      tags$div(
        style = "width:75%;",
        goliat_map_all_exploded
      ),
      
      tags$div(
        id = "edge-details",
        style = paste(
          "width:25%;",
          "height:900px;",
          "overflow-y:auto;",
          "padding:15px;",
          "border-left:1px solid #ccc;",
          "font-family:Arial;",
          "font-size:14px;"
        ),
        HTML("<h3>Edge details</h3><p>Exploded all-relationships view. Click a connection to see the individual supporting reference.</p>")
      )
    )
  )
)

goliat_map_all_exploded_with_panel

save_html(
  goliat_map_all_exploded_with_panel,
  file = "GOLIAT_Theme_All_exploded_with_panel.html"
)

# Save work
saveRDS(nodes_with_coords_sized,
        "nodes_with_coords_sized.rds")

saveRDS(edges_collapsed,
        "edges_collapsed.rds")

write.csv(
  edges_collapsed,
  "edges_collapsed.csv",
  row.names = FALSE
)

write.csv(
  nodes_with_coords_sized,
  "nodes_with_coords_sized.csv",
  row.names = FALSE
)

# Collapse edges
make_edges_collapsed <- function(data) {
  
  data %>%
    group_by(From, To, Relationship) %>%
    summarise(
      n_references = n_distinct(Reference),
      Themes = paste(sort(unique(Theme)), collapse = "|"),
      references_html = make_reference_blocks(Reference),
      .groups = "drop"
    ) %>%
    mutate(
      id = row_number(),
      from = From,
      to = To,
      label = Relationship,
      arrows = "to",
      value = n_references,
      width = 1 + log1p(n_references),
      
      color = case_when(
        Relationship == "Positive impact" ~ "darkgreen",
        Relationship == "Negative impact" ~ "darkred",
        TRUE ~ "grey50"
      ),
      
      title = paste0(
        "<b>", from, " → ", to, "</b><br>",
        "<b>Relationship:</b> ", Relationship, "<br>",
        "<b>Themes:</b> ", Themes, "<br>",
        "<b>References:</b> ", n_references, "<br>",
        "Click edge for full details."
      ),
      
      details_html = paste0(
        "<h3>", from, " → ", to, "</h3>",
        "<p><b>Relationship:</b> ", Relationship, "</p>",
        "<p><b>Themes:</b> ", Themes, "</p>",
        "<p><b>Number of references:</b> ", n_references, "</p>",
        "<h4>References</h4>",
        references_html
      )
    )
}

# Create and save theme-filtered maps
themes <- LETTERS[1:6]

for (theme_letter in themes) {
  
  connections_theme <- connections_raw %>%
    filter(Theme == theme_letter)
  
  edges_theme <- make_edges_collapsed(connections_theme)
  
  nodes_theme <- nodes_with_category_labels
  
  theme_descriptions <- c(
    A = "Impacts of internet-enabled device use and internet content on health",
    B = "Impacts of social media and online social networking on health",
    C = "Impacts of disordered online behaviour on health",
    D = "Impacts of internet-enabled device use on physical health",
    E = "Impacts of e-therapy interventions on health",
    `F` = "Impacts of e-health interventions on chronic disease outcomes"
  )
  
  theme_description <- tags$div(
    style = paste(
      "padding:12px 20px;",
      "background:#f8f9fa;",
      "border-bottom:1px solid #ddd;",
      "font-family:Arial;"
    ),
    
    tags$h3(
      style = "margin:0 0 6px 0;",
      paste("Theme", theme_letter)
    ),
    
    tags$p(
      style = "margin:0;",
      theme_descriptions[[theme_letter]]
    )
  )
  
  map_theme <- visNetwork(
    nodes_theme,
    edges_theme,
    width = "100%",
    height = "900px"
  ) %>%
    visGroups(
      groupname = category_levels[1],
      color = category_colours[[category_levels[1]]]
    ) %>%
    visNodes(shape = "dot", font = list(size = 30)) %>%
    visEdges(
      smooth = list(enabled = TRUE, type = "curvedCW", roundness = 0.2),
      font = list(size = 10, align = "middle"),
      color = list(inherit = FALSE)
    ) %>%
    visOptions(
      highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
      nodesIdSelection = FALSE
    ) %>%
    visInteraction(
      navigationButtons = TRUE,
      keyboard = TRUE,
      hover = TRUE,
      dragNodes = TRUE
    ) %>%
    visPhysics(enabled = FALSE) %>%
    visEvents(
      selectEdge = "
        function(params) {
          if (params.edges.length > 0) {
            var edgeId = params.edges[0];
            var edge = this.body.data.edges.get(edgeId);
            document.getElementById('edge-details').innerHTML = edge.details_html;
          }
        }
      "
    )
  
  map_theme_with_panel <- htmltools::browsable(
    htmltools::tagList(
      navigation_bar,
      relationship_legend,
      htmltools::tags$div(
        style = "display:flex; width:100%;",
        
        htmltools::tags$div(
          style = "width:75%;",
          map_theme
        ),
        
        htmltools::tags$div(
          id = "edge-details",
          style = paste(
            "width:25%;",
            "height:900px;",
            "overflow-y:auto;",
            "padding:15px;",
            "border-left:1px solid #ccc;",
            "font-family:Arial;",
            "font-size:14px;"
          ),
          htmltools::HTML(
            paste0(
              "<h2>Theme ", theme_letter, "</h2>",
    "<h3>", theme_descriptions[[theme_letter]], "</h3>",
    "<hr>",
    "<p>Click a connection to see references.</p>"
            )
          )
        )
      )
    )
  )
  
  htmltools::save_html(
    map_theme_with_panel,
    file = paste0("GOLIAT_Theme_", theme_letter, "_with_panel.html")
  )
}

# Create and save relationship-filtered maps
relationships <- c("Positive impact", "Negative impact")

for (rel in relationships) {
  
  rel_short <- if_else(rel == "Positive impact", "Positive", "Negative")
  
  connections_rel <- connections_raw %>%
    filter(Relationship == rel)
  
  edges_rel <- make_edges_collapsed(connections_rel)
  
  nodes_rel  <- nodes_with_category_labels
  
  map_rel <- visNetwork(
    nodes_rel,
    edges_rel,
    width = "100%",
    height = "900px"
  ) %>%
    visGroups(
      groupname = category_levels[1],
      color = category_colours[[category_levels[1]]]
    ) %>%
    visNodes(shape = "dot", font = list(size = 30)) %>%
    visEdges(
      smooth = list(enabled = TRUE, type = "curvedCW", roundness = 0.2),
      font = list(size = 10, align = "middle"),
      color = list(inherit = FALSE)
    ) %>%
    visOptions(
      highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
      nodesIdSelection = FALSE
    ) %>%
    visInteraction(
      navigationButtons = TRUE,
      keyboard = TRUE,
      hover = TRUE,
      dragNodes = TRUE
    ) %>%
    visPhysics(enabled = FALSE) %>%
    visEvents(
      selectEdge = "
        function(params) {
          if (params.edges.length > 0) {
            var edgeId = params.edges[0];
            var edge = this.body.data.edges.get(edgeId);
            document.getElementById('edge-details').innerHTML = edge.details_html;
          }
        }
      "
    )
  
  map_rel_with_panel <- htmltools::browsable(
    htmltools::tagList(
      navigation_bar,
      relationship_legend,
      htmltools::tags$div(
        style = "display:flex; width:100%;",
        
        htmltools::tags$div(
          style = "width:75%;",
          map_rel
        ),
        
        htmltools::tags$div(
          id = "edge-details",
          style = paste(
            "width:25%;",
            "height:900px;",
            "overflow-y:auto;",
            "padding:15px;",
            "border-left:1px solid #ccc;",
            "font-family:Arial;",
            "font-size:14px;"
          ),
          htmltools::HTML(
            paste0(
              "<h3>Edge details</h3>",
              "<p>", rel, " map. Click a connection to see references.</p>"
            )
          )
        )
      )
    )
  )
  
  htmltools::save_html(
    map_rel_with_panel,
    file = paste0("GOLIAT_", rel_short, "_with_panel.html")
  )
}

# Createmaps where edges are coloured by confounder status and strength of evidence
## Overall Confounder map: one connection per reference 
edges_confounder <- connections_raw %>%
  mutate(
    Confounder = stringr::str_squish(Confounder)
  ) %>%
  group_by(From, To) %>%
  mutate(
    n_parallel_edges = n(),
    edge_number = row_number(),
    curvature_value = if (n() == 1) {
      0.2
    } else {
      seq(0.05, 0.45, length.out = n())[edge_number]
    }
  ) %>%
  ungroup() %>%
  mutate(
    id = row_number(),
    from = From,
    to = To,
    label = Confounder,
    arrows = "to",
    width = 1.5,
    
    color = case_when(
      Confounder == "Implausible" ~ "#828eba",
      Confounder == "Possible" ~ "#d93434",
      Confounder == "Unlikely" ~ "#2d9930",
      TRUE ~ "#999999"
    ),

    smooth = purrr::map(
      curvature_value,
      ~list(
        enabled = TRUE,
        type = "curvedCW",
        roundness = .x
      )
    ),
    
    title = paste0(
      "<b>", from, " → ", to, "</b><br>",
      "<b>Relationship:</b> ", Relationship, "<br>",
      "<b>Confounder:</b> ", Confounder, "<br>",
      "<b>Theme:</b> ", Theme, "<br>",
      "Click edge for full details."
    )
  ) %>%
  rowwise() %>%
  mutate(
    details_html = paste0(
      "<h3>", from, " → ", to, "</h3>",
      "<p><b>Relationship:</b> ", Relationship, "</p>",
      "<p><b>Confounder:</b> ", Confounder, "</p>",
      "<p><b>Theme:</b> ", Theme, "</p>",
      "<h4>Reference</h4>",
      make_reference_blocks(Reference)
    )
  ) %>%
  ungroup()

goliat_map_confounder <- visNetwork(
  nodes_with_category_labels,
  edges_confounder,
  width = "100%",
  height = "900px"
) %>%
  visNodes(
    shape = "dot",
    font = list(size = 30)
  ) %>%
  visEdges(
    font = list(size = 10, align = "middle"),
    color = list(inherit = FALSE)
  ) %>%
  visOptions(
    highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
    nodesIdSelection = FALSE
  ) %>%
  visInteraction(
    navigationButtons = TRUE,
    keyboard = TRUE,
    hover = TRUE,
    dragNodes = TRUE
  ) %>%
  visPhysics(enabled = FALSE) %>%
  visEvents(
    selectEdge = "
      function(params) {
        if (params.edges.length > 0) {
          var edgeId = params.edges[0];
          var edge = this.body.data.edges.get(edgeId);
          document.getElementById('edge-details').innerHTML = edge.details_html;
        }
      }
    "
  )

confounder_legend <- htmltools::tags$div(
  style = "padding:10px; border-bottom:1px solid #ccc; font-family:Arial; font-size:14px;",
  htmltools::tags$b("Confounder legend: "),
  htmltools::tags$span(style = "display:inline-block; width:30px; height:4px; background:#d93434; margin:0 6px 3px 18px;"), "Possible",
  htmltools::tags$span(style = "display:inline-block; width:30px; height:4px; background:#2d9930; margin:0 6px 3px 18px;"), "Unlikely",
  htmltools::tags$span(style = "display:inline-block; width:30px; height:4px; background:#828eba; margin:0 6px 3px 12px;"), "Implausible",
)

goliat_map_confounder_with_panel <- htmltools::browsable(
  htmltools::tagList(
    navigation_bar,
    confounder_legend,
    htmltools::tags$div(
      style = "display:flex; width:100%;",
      
      htmltools::tags$div(
        style = "width:75%;",
        goliat_map_confounder
      ),
      
      htmltools::tags$div(
        id = "edge-details",
        style = paste(
          "width:25%;",
          "height:900px;",
          "overflow-y:auto;",
          "padding:15px;",
          "border-left:1px solid #ccc;",
          "font-family:Arial;",
          "font-size:14px;"
        ),
        htmltools::HTML(
          "<h3>Edge details</h3><p>Confounder view. Click a connection to see the reference-specific classification.</p>"
        )
      )
    )
  )
)

htmltools::save_html(
  goliat_map_confounder_with_panel,
  file = "GOLIAT_Confounder_with_panel.html"
)

## Overall evidence map: one connection per reference ----------------------------
edges_evidence <- connections_raw %>%
  mutate(
    Evidence = stringr::str_squish(Evidence)
  ) %>%
  group_by(From, To) %>%
  mutate(
    n_parallel_edges = n(),
    edge_number = row_number(),
    curvature_value = if (n() == 1) {
      0.2
    } else {
      seq(0.05, 0.45, length.out = n())[edge_number]
    }
  ) %>%
  ungroup() %>%
  mutate(
    id = row_number(),
    from = From,
    to = To,
    label = Evidence,
    arrows = "to",
    width = 1.5,
    
    color = case_when(
      Evidence == "Probable association" ~ "#F55600",
      Evidence == "Suggestive association" ~ "#F6BD97",
      Evidence == "Inconclusive (inconsistent or weak evidence)" ~ "#F4E167",
      Evidence == "Inconclusive (insufficient evidence)" ~ "#6BC24B",
      TRUE ~ "#999999"
    ),
    
    smooth = purrr::map(
      curvature_value,
      ~list(
        enabled = TRUE,
        type = "curvedCW",
        roundness = .x
      )
    ),
    
    title = paste0(
      "<b>", from, " → ", to, "</b><br>",
      "<b>Relationship:</b> ", Relationship, "<br>",
      "<b>Confounder:</b> ", Evidence, "<br>",
      "<b>Theme:</b> ", Theme, "<br>",
      "Click edge for full details."
    )
  ) %>%
  rowwise() %>%
  mutate(
    details_html = paste0(
      "<h3>", from, " → ", to, "</h3>",
      "<p><b>Relationship:</b> ", Relationship, "</p>",
      "<p><b>Evidence:</b> ", Evidence, "</p>",
      "<p><b>Theme:</b> ", Theme, "</p>",
      "<h4>Reference</h4>",
      make_reference_blocks(Reference)
    )
  ) %>%
  ungroup()

goliat_map_evidence <- visNetwork(
  nodes_with_category_labels,
  edges_evidence,
  width = "100%",
  height = "900px"
) %>%
  visNodes(
    shape = "dot",
    font = list(size = 30)
  ) %>%
  visEdges(
    font = list(size = 10, align = "middle"),
    color = list(inherit = FALSE)
  ) %>%
  visOptions(
    highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
    nodesIdSelection = FALSE
  ) %>%
  visInteraction(
    navigationButtons = TRUE,
    keyboard = TRUE,
    hover = TRUE,
    dragNodes = TRUE
  ) %>%
  visPhysics(enabled = FALSE) %>%
  visEvents(
    selectEdge = "
      function(params) {
        if (params.edges.length > 0) {
          var edgeId = params.edges[0];
          var edge = this.body.data.edges.get(edgeId);
          document.getElementById('edge-details').innerHTML = edge.details_html;
        }
      }
    "
  )

evidence_legend <- htmltools::tags$div(
  style = "padding:10px; border-bottom:1px solid #ccc; font-family:Arial; font-size:14px;",
  htmltools::tags$b("Evidence legend: "),
  htmltools::tags$span(style = "display:inline-block; width:30px; height:4px; background:#f55600; margin:0 6px 3px 18px;"), "Probable association",
  htmltools::tags$span(style = "display:inline-block; width:30px; height:4px; background:#f6bd97; margin:0 6px 3px 18px;"), "Suggestive association",
  htmltools::tags$span(style = "display:inline-block; width:30px; height:4px; background:#f4e167; margin:0 6px 3px 12px;"), "Inconclusive (inconsistent or weak evidence)",
  htmltools::tags$span(style = "display:inline-block; width:30px; height:4px; background:#6bc24b; margin:0 6px 3px 12px;"), "Inconclusive (insufficient evidence)"
)

goliat_map_evidence_with_panel <- htmltools::browsable(
  htmltools::tagList(
    navigation_bar,
    evidence_legend,
    htmltools::tags$div(
      style = "display:flex; width:100%;",
      
      htmltools::tags$div(
        style = "width:75%;",
        goliat_map_evidence
      ),
      
      htmltools::tags$div(
        id = "edge-details",
        style = paste(
          "width:25%;",
          "height:900px;",
          "overflow-y:auto;",
          "padding:15px;",
          "border-left:1px solid #ccc;",
          "font-family:Arial;",
          "font-size:14px;"
        ),
        htmltools::HTML(
          "<h3>Edge details</h3><p>Evidence view. Click a connection to see the reference-specific classification.</p>"
        )
      )
    )
  )
)

htmltools::save_html(
  goliat_map_evidence_with_panel,
  file = "GOLIAT_Evidence_with_panel.html"
)

# Make confounder- and evidence level maps
## Helper for creating safe filenames
clean_file_stub <- function(x) {
  x %>%
    stringr::str_replace_all("[()]", "") %>%
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") %>%
    stringr::str_replace_all("_+$", "")
}

## Confounder-level maps 
confounder_levels <- c(
  "Implausible",
  "Possible",
  "Unlikely"
)

for (conf_level in confounder_levels) {
  
  connections_conf <- connections_raw %>%
    mutate(Confounder = stringr::str_squish(Confounder)) %>%
    filter(Confounder == conf_level)
  
  edges_conf <- connections_conf %>%
    group_by(From, To) %>%
    mutate(
      n_parallel_edges = n(),
      edge_number = row_number(),
      curvature_value = if (n() == 1) {
        0.2
      } else {
        seq(0.05, 0.45, length.out = n())[edge_number]
      }
    ) %>%
    ungroup() %>%
    mutate(
      id = row_number(),
      from = From,
      to = To,
      label = Confounder,
      arrows = "to",
      width = 1.5,
      
      color = case_when(
        Confounder == "Implausible" ~ "#828eba",
        Confounder == "Possible" ~ "#d93434",
        Confounder == "Unlikely" ~ "#2d9930",
        TRUE ~ "#999999"
      ),
      
      smooth = purrr::map(
        curvature_value,
        ~list(enabled = TRUE, type = "curvedCW", roundness = .x)
      ),
      
      title = paste0(
        "<b>", from, " → ", to, "</b><br>",
        "<b>Relationship:</b> ", Relationship, "<br>",
        "<b>Confounder:</b> ", Confounder, "<br>",
        "<b>Theme:</b> ", Theme, "<br>",
        "Click edge for full details."
      )
    ) %>%
    rowwise() %>%
    mutate(
      details_html = paste0(
        "<h3>", from, " → ", to, "</h3>",
        "<p><b>Relationship:</b> ", Relationship, "</p>",
        "<p><b>Confounder:</b> ", Confounder, "</p>",
        "<p><b>Theme:</b> ", Theme, "</p>",
        "<h4>Reference</h4>",
        make_reference_blocks(Reference)
      )
    ) %>%
    ungroup()
  
  map_conf <- visNetwork(
    nodes_with_category_labels,
    edges_conf,
    width = "100%",
    height = "900px"
  ) %>%
    visNodes(shape = "dot", font = list(size = 30)) %>%
    visEdges(
      font = list(size = 10, align = "middle"),
      color = list(inherit = FALSE)
    ) %>%
    visOptions(
      highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
      nodesIdSelection = FALSE
    ) %>%
    visInteraction(
      navigationButtons = TRUE,
      keyboard = TRUE,
      hover = TRUE,
      dragNodes = TRUE
    ) %>%
    visPhysics(enabled = FALSE) %>%
    visEvents(
      selectEdge = "
        function(params) {
          if (params.edges.length > 0) {
            var edgeId = params.edges[0];
            var edge = this.body.data.edges.get(edgeId);
            document.getElementById('edge-details').innerHTML = edge.details_html;
          }
        }
      "
    )
  
  map_conf_with_panel <- htmltools::browsable(
    htmltools::tagList(
      navigation_bar,
      confounder_legend,
      htmltools::tags$div(
        style = "display:flex; width:100%;",
        htmltools::tags$div(style = "width:75%;", map_conf),
        htmltools::tags$div(
          id = "edge-details",
          style = paste(
            "width:25%;",
            "height:900px;",
            "overflow-y:auto;",
            "padding:15px;",
            "border-left:1px solid #ccc;",
            "font-family:Arial;",
            "font-size:14px;"
          ),
          htmltools::HTML(
            paste0(
              "<h3>Edge details</h3>",
              "<p>Confounder status: ", conf_level,
              ". Click a connection to see the reference-specific classification.</p>"
            )
          )
        )
      )
    )
  )
  
  htmltools::save_html(
    map_conf_with_panel,
    file = paste0(
      "GOLIAT_Confounder_",
      clean_file_stub(conf_level),
      "_with_panel.html"
    )
  )
}

## Evidence-level maps 
evidence_levels <- c(
  "Probable association",
  "Suggestive association",
  "Inconclusive (inconsistent or weak evidence)",
  "Inconclusive (insufficient evidence)"
)

for (ev_level in evidence_levels) {
  
  connections_ev <- connections_raw %>%
    mutate(Evidence = stringr::str_squish(Evidence)) %>%
    filter(Evidence == ev_level)
  
  edges_ev <- connections_ev %>%
    group_by(From, To) %>%
    mutate(
      n_parallel_edges = n(),
      edge_number = row_number(),
      curvature_value = if (n() == 1) {
        0.2
      } else {
        seq(0.05, 0.45, length.out = n())[edge_number]
      }
    ) %>%
    ungroup() %>%
    mutate(
      id = row_number(),
      from = From,
      to = To,
      label = Evidence,
      arrows = "to",
      width = 1.5,
      
      color = case_when(
        Evidence == "Probable association" ~ "#F55600",
        Evidence == "Suggestive association" ~ "#F6BD97",
        Evidence == "Inconclusive (inconsistent or weak evidence)" ~ "#F4E167",
        Evidence == "Inconclusive (insufficient evidence)" ~ "#6BC24B",
        TRUE ~ "#999999"
      ),
      
      smooth = purrr::map(
        curvature_value,
        ~list(enabled = TRUE, type = "curvedCW", roundness = .x)
      ),
      
      title = paste0(
        "<b>", from, " → ", to, "</b><br>",
        "<b>Relationship:</b> ", Relationship, "<br>",
        "<b>Evidence:</b> ", Evidence, "<br>",
        "<b>Theme:</b> ", Theme, "<br>",
        "Click edge for full details."
      )
    ) %>%
    rowwise() %>%
    mutate(
      details_html = paste0(
        "<h3>", from, " → ", to, "</h3>",
        "<p><b>Relationship:</b> ", Relationship, "</p>",
        "<p><b>Evidence:</b> ", Evidence, "</p>",
        "<p><b>Theme:</b> ", Theme, "</p>",
        "<h4>Reference</h4>",
        make_reference_blocks(Reference)
      )
    ) %>%
    ungroup()
  
  map_ev <- visNetwork(
    nodes_with_category_labels,
    edges_ev,
    width = "100%",
    height = "900px"
  ) %>%
    visNodes(shape = "dot", font = list(size = 30)) %>%
    visEdges(
      font = list(size = 10, align = "middle"),
      color = list(inherit = FALSE)
    ) %>%
    visOptions(
      highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
      nodesIdSelection = FALSE
    ) %>%
    visInteraction(
      navigationButtons = TRUE,
      keyboard = TRUE,
      hover = TRUE,
      dragNodes = TRUE
    ) %>%
    visPhysics(enabled = FALSE) %>%
    visEvents(
      selectEdge = "
        function(params) {
          if (params.edges.length > 0) {
            var edgeId = params.edges[0];
            var edge = this.body.data.edges.get(edgeId);
            document.getElementById('edge-details').innerHTML = edge.details_html;
          }
        }
      "
    )
  
  map_ev_with_panel <- htmltools::browsable(
    htmltools::tagList(
      navigation_bar,
      evidence_legend,
      htmltools::tags$div(
        style = "display:flex; width:100%;",
        htmltools::tags$div(style = "width:75%;", map_ev),
        htmltools::tags$div(
          id = "edge-details",
          style = paste(
            "width:25%;",
            "height:900px;",
            "overflow-y:auto;",
            "padding:15px;",
            "border-left:1px solid #ccc;",
            "font-family:Arial;",
            "font-size:14px;"
          ),
          htmltools::HTML(
            paste0(
              "<h3>Edge details</h3>",
              "<p>Evidence status: ", ev_level,
              ". Click a connection to see the reference-specific classification.</p>"
            )
          )
        )
      )
    )
  )
  
  htmltools::save_html(
    map_ev_with_panel,
    file = paste0(
      "GOLIAT_Evidence_",
      clean_file_stub(ev_level),
      "_with_panel.html"
    )
  )
}


# Create HTML index page
html <- '
<!DOCTYPE html>
<html>
<head>
  <title>Disentangling pathways between Internet-enabled device use and health: a systematic evidence map of reviews</title>
  <style>
    body {
      margin: 0;
      font-family: Arial, sans-serif;
      background: #f5f6f8;
      color: #222;
    }

    header {
      padding: 18px 28px;
      background: #1f2933;
      color: white;
    }

    header h1 {
      margin: 0;
      font-size: 24px;
    }

    header p {
      margin: 6px 0 0 0;
      font-size: 14px;
      color: #d5dce3;
    }

    .main-layout {
      display: flex;
      height: calc(100vh - 95px);
    }

    .sidebar {
      width: 245px;
      padding: 14px;
      background: white;
      border-right: 1px solid #ddd;
      box-sizing: border-box;
      overflow-y: auto;
    }

    .sidebar h2 {
      font-size: 15px;
      margin: 0 0 10px 0;
      color: #333;
    }
    
    .sidebar h3 {
      font-size: 13px;
      margin: 8 0 10px 0;
      color: #333;
    }
    
    .sidebar {
    width: 350px;
    padding: 14px;
    background: white;
    border-right: 1px solid #ddd;
    box-sizing: border-box;
    overflow-y: auto;
    }

    .sidebar button {
      display: block;
      width: 100%;
      margin-bottom: 8px;
      padding: 8px 10px;
      border: 1px solid #bbb;
      border-radius: 6px;
      background: #ffffff;
      cursor: pointer;
      font-size: 11px;
      text-align: left;
    }

    .sidebar button:hover {
      background: #eef3f8;
    }

    .sidebar button.active {
      background: #1f2933;
      color: white;
      border-color: #1f2933;
    }
    
    .button-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
    }
    
    .button-grid button {
    margin-bottom: 0;
    }

    .viewer {
      flex: 1;
      padding: 12px;
      box-sizing: border-box;
    }

    iframe {
      width: 100%;
      height: 100%;
      border: 1px solid #ccc;
      border-radius: 8px;
      background: white;
    }
  </style>
</head>

<body>

<header>
  <h1>Grellier et al. (2026) Disentangling pathways between Internet-enabled device use and health: a systematic evidence map of reviews</h1>
  <p>Interactive maps of relationships identified in the review. Zoom in to view names of nodes. Click a connection to view supporting references.</p>
</header>

<div class="main-layout">

  <nav class="sidebar">
    <h2>Map views</h2>
    <div class="button-grid">
    <button class="active" onclick="loadMap(this, \'GOLIAT_Theme_All_with_panel.html\')">All relationships</button>
    <button onclick="loadMap(this, \'GOLIAT_Theme_All_exploded_with_panel.html\')">All relationships (exploded)</button>
    </div>
    <h3>By nature of impact</h3>
    <div class="button-grid">
    <button onclick="loadMap(this, \'GOLIAT_Positive_with_panel.html\')">Positive impacts</button>
    <button onclick="loadMap(this, \'GOLIAT_Negative_with_panel.html\')">Negative impacts</button>
    </div>
    <h3>By theme</h3>
    <div class="button-grid">
    <button onclick="loadMap(this, \'GOLIAT_Theme_A_with_panel.html\')">Theme A</button>
    <button onclick="loadMap(this, \'GOLIAT_Theme_B_with_panel.html\')">Theme B</button>
    <button onclick="loadMap(this, \'GOLIAT_Theme_C_with_panel.html\')">Theme C</button>
    <button onclick="loadMap(this, \'GOLIAT_Theme_D_with_panel.html\')">Theme D</button>
    <button onclick="loadMap(this, \'GOLIAT_Theme_E_with_panel.html\')">Theme E</button>
    <button onclick="loadMap(this, \'GOLIAT_Theme_F_with_panel.html\')">Theme F</button>
    </div>
    <h3>By confounder status</h3>
    <div class="button-grid">
    <button onclick="loadMap(this, \'GOLIAT_Confounder_with_panel.html\')">All</button>
    <button onclick="loadMap(this, \'GOLIAT_Confounder_Possible_with_panel.html\')">Possible</button>
    <button onclick="loadMap(this, \'GOLIAT_Confounder_Unlikely_with_panel.html\')">Unlikely</button>
    <button onclick="loadMap(this, \'GOLIAT_Confounder_Implausible_with_panel.html\')">Implausible</button>
    </div>
    <h3>By strength of evidence</h3>
    <button onclick="loadMap(this, \'GOLIAT_Evidence_with_panel.html\')">All</button>
    <button onclick="loadMap(this, \'GOLIAT_Evidence_Probable_association_with_panel.html\')">Probable</button>
    <button onclick="loadMap(this, \'GOLIAT_Evidence_Suggestive_association_with_panel.html\')">Suggestive</button>
    <button onclick="loadMap(this, \'GOLIAT_Evidence_Inconclusive_inconsistent_or_weak_evidence_with_panel.html\')">Inconclusive (inconsistent/weak evidence)</button>
    <button onclick="loadMap(this, \'GOLIAT_Evidence_Inconclusive_insufficient_evidence_with_panel.html\')">Inconclusive (insufficient evidence)</button>
  </nav>

  <main class="viewer">
    <iframe id="mapFrame" src="GOLIAT_Theme_All_with_panel.html"></iframe>
  </main>

</div>

<script>
function loadMap(button, file) {
  document.getElementById("mapFrame").src = file;

  var buttons = document.querySelectorAll(".sidebar button");
  buttons.forEach(function(btn) {
    btn.classList.remove("active");
  });

  button.classList.add("active");
}
</script>

</body>
</html>
'

writeLines(html, "index.html")
