library(plumber)
library(tidymodels)
library(readr)
library(dplyr)
library(ggplot2)

# Read the data
water <- read_csv(
  "data/water_potability.csv",
  show_col_types = FALSE
) |>
  mutate(
    Potability = factor(
      Potability,
      levels = c(0, 1),
      labels = c("Not Potable", "Potable")
    )
  )

# Use the best mtry value from the modeling file
best_mtry <- 3

# Handle missing values
water_recipe <- recipe(
  Potability ~ .,
  data = water
) |>
  step_impute_median(all_numeric_predictors())

# Set up the random forest model
rf_model <- rand_forest(
  mtry = best_mtry,
  trees = 1000,
  min_n = 5
) |>
  set_engine("ranger", probability = TRUE) |>
  set_mode("classification")

# Combine the recipe and model
rf_workflow <- workflow() |>
  add_recipe(water_recipe) |>
  add_model(rf_model)

# Fit the model to the full dataset
final_model <- fit(
  rf_workflow,
  data = water
)

# Default values for the prediction endpoint
default_ph <- mean(water$ph, na.rm = TRUE)
default_hardness <- mean(water$Hardness, na.rm = TRUE)
default_solids <- mean(water$Solids, na.rm = TRUE)
default_chloramines <- mean(water$Chloramines, na.rm = TRUE)
default_sulfate <- mean(water$Sulfate, na.rm = TRUE)
default_conductivity <- mean(water$Conductivity, na.rm = TRUE)
default_organic_carbon <- mean(water$Organic_carbon, na.rm = TRUE)
default_trihalomethanes <- mean(water$Trihalomethanes, na.rm = TRUE)
default_turbidity <- mean(water$Turbidity, na.rm = TRUE)

#* Predict water potability
#* @param ph Water pH
#* @param Hardness Water hardness
#* @param Solids Dissolved solids
#* @param Chloramines Chloramine level
#* @param Sulfate Sulfate level
#* @param Conductivity Water conductivity
#* @param Organic_carbon Organic carbon level
#* @param Trihalomethanes Trihalomethane level
#* @param Turbidity Water turbidity
#* @get /pred
function(
    ph = default_ph,
    Hardness = default_hardness,
    Solids = default_solids,
    Chloramines = default_chloramines,
    Sulfate = default_sulfate,
    Conductivity = default_conductivity,
    Organic_carbon = default_organic_carbon,
    Trihalomethanes = default_trihalomethanes,
    Turbidity = default_turbidity
) {
  
  new_water <- tibble(
    ph = as.numeric(ph),
    Hardness = as.numeric(Hardness),
    Solids = as.numeric(Solids),
    Chloramines = as.numeric(Chloramines),
    Sulfate = as.numeric(Sulfate),
    Conductivity = as.numeric(Conductivity),
    Organic_carbon = as.numeric(Organic_carbon),
    Trihalomethanes = as.numeric(Trihalomethanes),
    Turbidity = as.numeric(Turbidity)
  )
  
  class_result <- predict(
    final_model,
    new_data = new_water,
    type = "class"
  )
  
  probability_result <- predict(
    final_model,
    new_data = new_water,
    type = "prob"
  )
  
  results <- bind_cols(
    class_result,
    probability_result
  )
  
  list(
    prediction = as.character(results$.pred_class),
    probability_not_potable = probability_result[[1]],
    probability_potable = probability_result[[2]]
  )
}

# Example calls:
# http://127.0.0.1:8000/pred
# http://127.0.0.1:8000/pred?ph=7&Hardness=200&Solids=20000
# http://127.0.0.1:8000/pred?ph=6.5&Hardness=180&Solids=15000&Chloramines=7&Sulfate=330&Conductivity=420&Organic_carbon=14&Trihalomethanes=65&Turbidity=4

#* Show project information
#* @get /info
function() {
  list(
    name = "Ralph Church",
    website = "https://github.com/rchurch3-stack/ST558FinalProject/"
  )
}

# Make predictions for the full dataset
full_predictions <- predict(
  final_model,
  new_data = water,
  type = "class"
) |>
  bind_cols(
    water |>
      select(Potability)
  )

# Create the confusion matrix
water_confusion <- conf_mat(
  full_predictions,
  truth = Potability,
  estimate = .pred_class
)

#* Show the confusion matrix
#* @serializer png
#* @get /confusion
function() {
  
  confusion_plot <- autoplot(
    water_confusion,
    type = "heatmap"
  ) +
    labs(
      title = "Random Forest Confusion Matrix",
      x = "Predicted",
      y = "Actual"
    )
  
  print(confusion_plot)
}