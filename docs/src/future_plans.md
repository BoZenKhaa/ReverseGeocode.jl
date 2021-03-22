# Future plans

## Improve the accuracy of labelling
The package intrinsically provides only approximate tags for locations. There seems to be more than one sources of errors:
 - the labelled point is closer to reference point in another country, district, ... than to the correct reference point. 
 - the labelled point is closer to the correct reference point using the real (Haversine) distance, but since the method uses euclidian distance on lat/lon coordinates, it could come out closer to an incorrect reference point. 

The first point is difficult to fix without using polygons for districts and countries. The second point could be easily fixed by using a haversine formula (probably an overkill) or simply compensating for the different lat/lon degree length (WE degrees have different length at different lattitudes) with simple cosine formula. To implement this, I would like to gather a test dataset first to determine whether the more complex calculation is worth the effort. Some reported inaccuracies can be found [here](https://github.com/thampiman/reverse-geocoder/issues).

## Change installation and usage
Right now, the database of reference points is downloaded upon first use of Geocoder. I think it would be better to add a build step to the installation in which the database would get downloaded and preprocessed. 

## Add more optional administrative units to the output
This should be easy since all the data is already there

## Allow user defined inputs 
This should be easy as well since all the functions take kwarg with a path to the database file.