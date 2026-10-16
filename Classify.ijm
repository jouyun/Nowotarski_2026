//setTool("polygon");
//setTool("rectangle");
lineseparator = "\n";
cellseparator = ",\t";

// copies the whole RT to an array of lines
lines=split(File.openAsString(""), lineseparator);

// recreates the columns headers
labels=split(lines[0], cellseparator);
IJ.log(labels[0]);
if (labels[0]==" ")
k=1; // it is an ImageJ Results table, skip first column
else
k=0; // it is not a Results table, load all columns
for (j=k; j<labels.length; j++)
setResult(labels[j],0,0);

// dispatches the data into the new RT
run("Clear Results");
for (i=1; i<lines.length; i++) {
items=split(lines[i], cellseparator);
for (j=k; j<items.length; j++)
   setResult(labels[j],i-1,items[j]);
}
updateResults();
//open("S:/micro/asa/stn/mel/20-15_Irradiation_Datasets/20210721_MER_IMARE-106746_20_15_1A_control/20-15-1A_after_crash/cjw/DeepLearn/Classifier/Test/0000_control.tif");
//run("Classify Individual Files");

run("Classify Individual Files", "zoom?");
//run("Classify Individual Files", " ");