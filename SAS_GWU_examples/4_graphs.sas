******************************************************************************;
* Copyright (c) 2015 by SAS Institute Inc., Cary, NC 27513 USA               *;
*                                                                            *;
* Licensed under the Apache License, Version 2.0 (the "License");            *;
* you may not use this file except in compliance with the License.           *;
* You may obtain a copy of the License at                                    *;
*                                                                            *;
*   http://www.apache.org/licenses/LICENSE-2.0                               *;
*                                                                            *;
* Unless required by applicable law or agreed to in writing, software        *;
* distributed under the License is distributed on an "AS IS" BASIS,          *;
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   *;
* See the License for the specific language governing permissions and        *;
* limitations under the License.                                             *;
******************************************************************************;

******************************************************************************;
* SECTION 4 - generating analytical graphics                                 *;
******************************************************************************;

*** histograms using PROC SGPLOT *********************************************;

proc sgplot 
	/* binwidth - bin width in terms of histogram variable */
	/* datalabel - display counts or percents for each bin */
	/* showbins - use bins to determine x-axis tickmarks */
	data=sashelp.iris;
	histogram petalwidth /
		binwidth=2
		datalabel=count
		showbins;
run;

*** bubble plots using PROC SGPLOT *******************************************;

proc sgplot
	/* group - color by a categorical variable */
	/* lineattrs - sets the bubble outline color and other outline attributes */
	data=sashelp.iris;
	bubble x=petalwidth y=petallength size=sepallength /
		group=species
		lineattrs=(color=grey);
run;

*** scatter plot with regression information using PROC SGPLOT ***************;

proc sgplot 
	/* clm - confidence limits for mean predicted values */
	/* cli - prediction limits for individual predicted values */
	/* alpha - set threshold for clm and cli limits */
	data=sashelp.iris;
	reg x=petalwidth y=petallength /
	clm cli alpha=0.1;
run;

*** stacked bar chart using PROC SGPLOT **************************************;

proc sgplot 
	/* vbar variable on x-axis */
	/* group - splits vertical bars */
	/* add title */
	data=sashelp.cars;
	vbar type / group=origin;
	title 'Car Types by Country of Origin';
run;

*** correlation heatmap using GTL ********************************************;

* use PROC CORR to create correlation matrix;
* create corr set;
proc corr
	data=sashelp.cars
	outp=corr
	noprint;
run;

* change correlation matrix into x y z contours;
* x and y will be variable names;
* z will be correlation values;
* create xyz set;
data xyz;

	/* define an array out of the numeric variables in corr */
	/* move backwards across array */
	/* to preserve traditional correlation matrix appearance */

	keep x y z;
	set corr(where=(_type_='CORR'));
	array zs[*] _numeric_;
	x = _NAME_;
	do i = dim(zs) to 1 by -1;
		y = vname(zs[i]);
		z = zs[i];
		/* creates a lower triangular matrix */
		if (i < _n_) then z = .;
		output;
	end;
run;

* define a GTL template;
* create the corrheatmap template;
* define a template once, then it can be rendered many times;
proc template;

	/* name the statgraph template */
	/* define a dynamic title for the template */
	/* overlay a continous legend on top of a heatmap */
	/* define overlay axes options */
	/* define heatmap options */
	/* define legend options */

	define statgraph corrheatmap;
		dynamic _title;
		begingraph;
			entrytitle _title;
			layout overlay /
				xaxisopts=(display=(line ticks tickvalues)) 
				yaxisopts=(display=(line ticks tickvalues));
				heatmapparm x=x y=y colorresponse=z / 
					xbinaxis=false ybinaxis=false
					name="heatmap" display=all;
				continuouslegend "heatmap" / 
					orient=vertical location=outside title="Correlation";
			endlayout;
		endgraph;
	end;
run;

* render the defined template using xyz set;
proc sgrender
	data=xyz 
	/* refers to defined template by name */
	template=corrheatmap;
	/* passes in title to template */
	dynamic _title='Correlation Heat Map for Car Information';
run;