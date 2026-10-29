library(ggplot2)

theme_dataforge <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.title.position = "plot",
      legend.position = "top",
      panel.grid.minor = element_blank()
    )
}