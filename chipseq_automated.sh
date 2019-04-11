#! /bin/bash

#echo "Enter ref file, ChIP-seq file and control file"

mkdir ../chipseq_bashscript

#---------------------------------

#CONFIRM ENOUGH FILES ARE SPECIFIED

if [ $# != 3 ]; then
    echo "Not enough files: Reference, ChIP-seq and control file needed"
fi

#---------------------------------
##CONFIRM FILES ARE READABLE
declare -a PARAM

PARAM=($1 $2 $3)

filesaccepted() {
tmp=("$@")	
for file in ${tmp[@]};
	do
  		if [[ -f $file && -r $file ]];
        	then
            		echo "File is a readable file"
        	else
                	echo "File is not a readable file"
       		fi
#--------------------------------
    
#CHECK FILE TYPES

if [[ ${1: -3} != ".fa" ]]; then
    echo "Reference data has incompatible file type."
    exit 1

fi

if [[ ${2: -6} != ".fastq" ]]; then
    echo "ChIP-seq data is incompatible file type."
    exit 1

fi

if [[ ${3: -6} != ".fastq" ]]; then
    echo "Control data is incompatible type."
    exit 1
fi

done
}

filesaccepted "${PARAM[@]}"


#-------------------------

##CONFIRM FILES ARE READABLE
declare -a PARAM
PARAM=($1 $2 $3)

for file in ${PARAM[@]}; 
do
	if [[ -f $file && -r $file ]]; 
	then
		echo "File is a readable file"
	else
		echo "File is not a readable file"
	fi
done

#--------------------------
	    
##CREATE FILE VARIABLES

ref=$1
chip=$2
control=$3

##LOAD REQUIRED MODULES
#fastqc
module load fastqc #preprocessing

#bowtie
module load bowtie #alignment

 

##INITIAL QC
#2. PERFORM QC ON CHIP and INPUT 
fastqc $chip
fastqc $control

##SEQUENCE ALIGNMENT
#2. Build the chromosome with bowtie2
#2.1 Create chromosome index
bowtie2-build $ref hg19

#2.2 Create SAM files
bowtie2 -x hg19 -U $chip -S chip.sam
bowtie2 -x hg19 -U $control -S input.sam

#samtools
module load samtools #alignment postprocessing 

##ALIGNMENT POSTPROCESSING
#2. create BAM files
samtools view -Sb input.sam > input.bam
samtools view -Sb chip.sam > chip.bam


#3. remove duplicates
samtools rmdup chip.bam chip.rmdup.bam
samtools rmdup input.bam input.rmdup.bam

#4. sort the files
samtools sort chip.rmdup.bam chip.rmdup.sorted
samtools sort input.rmdup.bam input.rmdup.sorted

#5. index the BAM files
samtools index chip.rmdup.sorted.bam
samtools index input.rmdup.sorted.bam

#6. Generate mapping statistics

samtools flagstat chip.rmdup.sorted.bam > chip_mappingstats.txt
samtools flagstat input.rmdup.sorted.bam > input_mappingstats.txt


##3. PEAK CALLING
#1. Generate XLS files
macs2 callpeak -t chip.rmdup.sorted.bam -c input.rmdup.sorted.bam -f BAM -g hs -n macs_out --call-summits -B

#2. Extract the peaks
awk '{print $1,$2,$3}' macs_out_peaks.xls > peaks.bed

#3. Copy necessary files to scp
cp chip.rmdup.sorted.* input.rmdup.sorted.* chip.bam input.bam macs_out* ../chipseq_bashscript


