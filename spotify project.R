data <- read.csv("spotify_data.csv")
library(tidyverse)



colnames(data)
view(unique(data$genre))

subset <- head(data,7000)
view(subset)
write.csv(subset, "subset.csv")

range(data$popularity)

str(data) 

colSums(is.na(data)) #no NAs


#checking number of genres
genre_count <- data %>% group_by(genre) %>% summarise(count = n())
view(genre_count)
genre_count_sorted <- genre_count[rev(order(genre_count$count)),]
view(genre_count_sorted)

##############################################################################################################

#viz
library(ggridges)

#(1) genre and popularity:
#get the most popular genres:
top_genres <- data %>%
  group_by(genre) %>%
  summarise(avg_popularity = mean(popularity, na.rm = TRUE)) %>%
  arrange(-avg_popularity) %>%
  head(10)  

top_genre_names <- top_genres$genre

filtered_data_frame <- data %>% filter(genre %in% top_genre_names)

ggplot(filtered_data_frame, aes(x = popularity, y = genre, fill = genre)) +
  geom_density_ridges() +
  ggtitle("Popularity by Top Genres") +
  xlab("Popularity") +
  ylab("Genre") +
  theme_ridges() +
  theme(legend.position = "none")


#(2)popularity vs year:
ggplot(data, aes(x = year, y = popularity)) +
  geom_point() +
  geom_smooth(method = 'lm') +
  ggtitle("Popularity vs. Year") +
  xlab("Year") +
  ylab("Popularity")

#####################################################################################################################################


#Popularity and Song attributes:

#regular multivariate regression with handpicked predictors:
set.seed(123)
multivariate_fit <- lm(popularity ~ danceability + energy + acousticness + instrumentalness + valence, data = data)
summary(multivariate_fit)

#Call:
# lm(formula = popularity ~ danceability + energy + acousticness + 
#     instrumentalness + valence, data = data)

#Residuals:
#  Min      1Q  Median      3Q     Max 
#-29.660 -12.699  -2.791  10.327  78.365 

#Coefficients:
# Estimate Std. Error t value Pr(>|t|)    
#(Intercept)      22.01642    0.08759  251.37   <2e-16 ***
# danceability     11.40266    0.09337  122.12   <2e-16 ***
#energy           -4.53886    0.08510  -53.34   <2e-16 ***
#acousticness     -4.07022    0.06353  -64.07   <2e-16 ***
#instrumentalness -7.75356    0.04186 -185.22   <2e-16 ***
#valence          -7.88653    0.06758 -116.70   <2e-16 ***

#  Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

#Residual standard error: 15.5 on 1159758 degrees of freedom


#Multiple R-squared:  0.04736,	Adjusted R-squared:  0.04735 
#F-statistic: 1.153e+04 on 5 and 1159758 DF,  p-value: < 2.2e-16


#There is statistical significance for all the predictors but low R squared value.

#Visualizing the co-effiencets:
coef_df <- broom::tidy(multivariate_fit)

ggplot(coef_df, aes(x = term, y = estimate, ymin = estimate - std.error, ymax = estimate + std.error)) +
  geom_pointrange() +  
  geom_hline(yintercept = 0, linetype = "dashed", color = "darkred") +
  labs(title = "Coefficient Plot", x = "Predictors", y = "Coefficients") +
  theme_minimal() +  
  theme(axis.text.x = element_text(angle = 45, hjust = 1))  



###################################################################################################################]
# Checking for issues that may have led to low r squared value: 

#(1) Checking for multicoolineraity:
library(reshape2)
library(corrplot)
library(car)


vif_values <- vif(multivariate_fit)
vif_values

#danceability           energy     acousticness instrumentalness          valence 
#1.431458         2.556267         2.453694         1.126739         1.588528 

#not a high degree (under 5) so we can mostly ignore this as an issue

#correlation matrix viz
cor_matrix <- cor(data[, c('popularity', 'danceability', 'energy', 'acousticness', 'instrumentalness', 'valence')], use = "complete.obs")  


# Create the correlation plot
corrplot(cor_matrix, method= "circle",
         number.cex = 0, 
         tl.cex = 0.9,    
         tl.col = "black",  
         cl.cex = 0.8,    
         mar = c(0.7, 0.7, 0.7, 0.7),  
         tl.srt = 45)  



# (2) Checking for heteroscedasticity:
library(lmtest)  
bptest(multivariate_fit) 

#	studentized Breusch-Pagan test

#data:  multivariate_fit
#BP = 30971, df = 5, p-value < 2.2e-16


#the p value is very low and below 0.05. Thus, heteroscedasticity is present which is impacting the multivariate model as that model assumes homoscedasticity

################################################################################################################################################
#Visualize heteroscedasticity:
ggplot(multivariate_fit, aes(.fitted, .resid)) +
  geom_point() +
  geom_smooth(method = "loess", col = "red") +
  labs(x = "Fitted values", y = "Residuals", title = "Residuals vs Fitted Values Plot") +
  theme_minimal()

#This vizualisation is taking over 40 mins and it still has not run. I will try subsetting the data just for the vizualization:

set.seed(123)
data_sample <- data[sample(nrow(data), 10000), ]

# Fit the model to the subset
set.seed(123)
model_subset <- lm(popularity ~ danceability + energy + acousticness + instrumentalness + valence, data = data_sample)

# Create the plot
ggplot(model_subset, aes(.fitted, .resid)) +
  geom_point(alpha = 0.5) + 
  geom_smooth(method = "loess", col = "red") +
  labs(x = "Fitted values", y = "Residuals", title = "Residuals vs Fitted Values Plot (Subset)") +
  theme_minimal()

#This shows heteroscedasticity is present and the curve also implies the relationship isn't fully linear - we will address this second point after attempting to deal with heteroscedasticity


##############################################################################################################################
#Dealing with heteroscedasticity:

# Option 1: Transformation of dependant variable 

#To deal with this issues, there are several options. First, I can transform the dependent variables using things like square roots and logarithms
#Logs are helpful when the data spans many orders of magnitude (not true here), or if the data is skewed. 
#Testing for skewedness:
ggplot(data, aes(x = popularity)) +
  geom_histogram(aes(y = ..density..), bins = 30, fill = "darkblue", alpha = 0.7) +
  geom_density(alpha = .2, fill = "darkred") +
  labs(title = "Histogram of Popularity - checking for 'skewness'", x = "Popularity", y = "Density")

#This looks very skewed (much fewer songs have high popularity) so I will proceed with a log transformation for regression:

#Regression with log transformation of popularity:
data$popularity_log <- log1p(data$popularity)

set.seed(123)
log_transformed_fit <- lm(popularity_log ~ danceability + energy + acousticness + instrumentalness + valence, data = data)

summary(log_transformed_fit)

#Call:
# lm(formula = popularity_log ~ danceability + energy + acousticness + 
#    instrumentalness + valence, data = data)

#Residuals:
#  Min      1Q  Median      3Q     Max 
#-3.0823 -0.6681  0.3537  0.9446  2.4625 

#Coefficients:
# Estimate Std. Error t value Pr(>|t|)    
#(Intercept)       2.835045   0.006955  407.62   <2e-16 ***
# danceability      0.440128   0.007415   59.36   <2e-16 ***
#  energy           -0.243350   0.006758  -36.01   <2e-16 ***
#  acousticness     -0.303733   0.005045  -60.21   <2e-16 ***
#  instrumentalness -0.550027   0.003324 -165.46   <2e-16 ***
#  valence          -0.561371   0.005366 -104.61   <2e-16 ***
# Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

#Residual standard error: 1.231 on 1159758 degrees of freedom
#Multiple R-squared:  0.03254,	Adjusted R-squared:  0.03254 
#F-statistic:  7802 on 5 and 1159758 DF,  p-value: < 2.2e-16

#The r sqaured value got even worse


#Checking for heteroscedasticity:
bptest(log_transformed_fit)

#studentized Breusch-Pagan test
#data:  log_transformed_fit
#BP = 10090, df = 5, p-value < 2.2e-16

#So the transformationm does not address the problem of heteroscedasticity either

###################################################################################################################################################

# Option 2: WLS regression

# Estimating weights
weights <- 1 / residuals(multivariate_fit)^2

#RWLS regression
set.seed(123)
model_wls <- lm(popularity ~ danceability + energy + acousticness + instrumentalness + valence, data = data, weights = weights)


summary(model_wls)

#Call:
# lm(formula = popularity ~ danceability + energy + acousticness + 
#     instrumentalness + valence, data = data, weights = weights)

#Weighted Residuals:
#  Min     1Q Median     3Q    Max 
#-1.228 -1.000 -1.000  1.000  1.942 

#Coefficients:
# Estimate Std. Error t value Pr(>|t|)    
#(Intercept)       2.202e+01  2.083e-04  105692   <2e-16 ***
#  danceability      1.140e+01  6.251e-05  182408   <2e-16 ***
#  energy           -4.539e+00  1.928e-04  -23540   <2e-16 ***
#  acousticness     -4.070e+00  1.516e-04  -26848   <2e-16 ***
#  instrumentalness -7.754e+00  7.280e-05 -106503   <2e-16 ***
#  valence          -7.887e+00  1.499e-04  -52632   <2e-16 ***

#  Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

#Residual standard error: 1 on 1159758 degrees of freedom
#Multiple R-squared:      1,	Adjusted R-squared:      1 
#F-statistic: 9.795e+09 on 5 and 1159758 DF,  p-value: < 2.2e-16

#There has to be a crazy amount of overfitting to get a r squared value of 1

#Checking for heteroscedasticity:
bptest(model_wls)

#studentized Breusch-Pagan test

#data:  model_wls
#BP = 87205, df = 5, p-value < 2.2e-16



#This could also be due to my choice in weights but I am not sure how to proceed with weight selection beyond this

#############################################################################################################################

#Option 3: Generalized Additive Models:

#My attempst at linear models have failed so far, as suggested by the graph for heteroscedasticity perhaps the relationship is simply too non-linear for such models to capture - eamining this:


#Chceking for non-linear relationships:

#danceability
ggplot(data_sample, aes(x = danceability, y = popularity)) + geom_point() + geom_smooth(method = "loess") + labs(title = "danceability")

#energy
ggplot(data_sample, aes(x = energy, y = popularity)) + geom_point() + geom_smooth(method = "loess") + labs(title = "energy")

#acousticness
ggplot(data_sample, aes(x = acousticness, y = popularity)) + geom_point() + geom_smooth(method = "loess") +  labs(title = "acousticness")

#instrumentalness
ggplot(data_sample, aes(x = instrumentalness, y = popularity)) + geom_point() + geom_smooth(method = "loess") + labs(title = "instrumentalness")

#valence
ggplot(data_sample, aes(x = valence, y = popularity)) + geom_point() + geom_smooth(method = "loess") + labs(title = "valence")

#It looks like instrumentalness and energy have non-linear relationships with popularity, so I will smooth these out in my model:

library(mgcv)
library(caret)

set.seed(123)
gam_model <- gam(popularity ~ s(instrumentalness) + s(energy) + acousticness + danceability + valence, data = data)
summary(gam_model)

#Family: gaussian 
#Link function: identity 

#Formula:
# popularity ~ s(instrumentalness) + s(energy) + acousticness + 
#danceability + valence

#Parametric coefficients:
# Estimate Std. Error t value Pr(>|t|)    
#(Intercept)  17.72038    0.05382  329.23   <2e-16 ***
# acousticness -3.99214    0.06514  -61.28   <2e-16 ***
#danceability 11.26895    0.09687  116.33   <2e-16 ***
#valence      -9.02179    0.06833 -132.03   <2e-16 ***

#  Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

#Approximate significance of smooth terms:
#  edf Ref.df    F p-value    
#s(instrumentalness) 8.997      9 4865  <2e-16 ***
#  s(energy)           8.993      9 1015  <2e-16 ***

#  Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

#R-sq.(adj) =  0.0606   Deviance explained = 6.06%
#GCV = 237.07  Scale est. = 237.07    n = 1159764


#Checking for heteroscedasticity:
bptest(gam_model)

#studentized Breusch-Pagan test

#data:  gam_model
#BP = 30971, df = 5, p-value < 2.2e-16

#heteroscadascity is still high and present

#######################################################################################################################

#Option 4: Random Forests

#Given that heteroscasdascity is present in so many of these models, I will choose one for which its pressence woyuld not make any big imp[act: random forests

# This is because RFs do not assume any distributions in the data when modelling and simply take the averages of predictions of many decision trees:

library(ranger)
set.seed(123)
rf_model <- ranger(popularity ~ danceability + energy + acousticness + instrumentalness + valence, 
                   data = data, 
                   importance = 'impurity', 
                   num.trees = 500,        
                   verbose = TRUE)

rf_model

#Ranger result

#Call:
#  ranger(popularity ~ danceability + energy + acousticness + instrumentalness +      valence, data = data, importance = "impurity", num.trees = 500,      verbose = TRUE) 

#Type:                             Regression 
#Number of trees:                  500 
#Sample size:                      1159764 
#Number of independent variables:  5 
#Mtry:                             2 
#Target node size:                 5 
#Variable importance mode:         impurity 
#Splitrule:                        variance 
#OOB prediction error (MSE):       224.8958 
#R squared (OOB):                  0.1087959 


# The r squared value means the model can predict about 10% of the variance in popularity of a song - higher than all the previous models (in some case twice as much) but still kind of low

# The OOB prediction error & RMSE (which should just be the square root which is approx 15), when taken in context of the 'range' of popularity (0-100) means that the model has an error of about '15' on a range of 0-100

#This can be explained by the fact that many many more factors go into dictating the popularity of a song than just the variables in this dataset
#These include many external factors like trends, popularity of the artists, marketing of the song, virality, etc.

#Thus, over our numerous analyses, we can conclude that while our chosen predictors are statically significant, many other, more important factors go into determining song popularity


# Predict using the model
set.seed(123)
predictions_rf_model <- predict(rf_model, data = data)$predictions

# Calculate residuals
residuals_rf_model <- data$popularity - predictions_rf_model

# Calculate RMSE
rmse_rf_model <- sqrt(mean(residuals_rf_model^2))


rmse_rf_model
#[1] 6.865623


#However, it looks like overfitting is present as the RMSE on predictions (6) is much lower than OOB (MSE) calculated on the rf model (sqr root of 224.8 = 15)


################################################################################################################################
# Random Forest model with adjusted parameters for overfitting
set.seed(123)
rf_model_adjusted <- ranger(
  popularity ~ danceability + energy + acousticness + instrumentalness + valence, 
  data = data, 
  num.trees = 500,
  mtry = 2,
  min.node.size = 10,  # Adjusting node size 
  max.depth = 5,        # Limiting depth 
  importance = 'impurity'
)


rf_model_adjusted

#Ranger result

#Call:
# ranger(popularity ~ danceability + energy + acousticness + instrumentalness +      valence, data = data, num.trees = 500, mtry = 2, min.node.size = 10,      max.depth = 5, importance = "impurity") 

#Type:                             Regression 
#Number of trees:                  500 
#Sample size:                      1159764 
#Number of independent variables:  5 
#Mtry:                             2 
#Target node size:                 10 
#Variable importance mode:         impurity 
#Splitrule:                        variance 
#OOB prediction error (MSE):       229.9204 
#R squared (OOB):                  0.08888484 


#RMSE according to the model is approx. 15.16 (sqr root of 229.9204)


set.seed(123)
predictions_rf_model_adjusted <- predict(rf_model_adjusted, data = data)$predictions

#residuals
residuals_rf_model_adjusted <- data$popularity - predictions_rf_model_adjusted

#RMSE
rmse_rf_model_adjusted <- sqrt(mean(residuals_rf_model_adjusted^2))


rmse_rf_model_adjusted
#[1] 15.15653

#ovefitting looks to eliminated now comapring square root of OOB from the adjusted RF model and RMSE from predictions - they are almost identical!!!
#verified


