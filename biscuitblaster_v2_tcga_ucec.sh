#!/bin/bash
set -euxo pipefail

#This script is intended to generate a job script that can be submitted to a PBS manager
#To generate the job scripts
#1) Modify any of the paths/function calls/etc below to meet the analysis needs/tool used
#2) bash your_generator.sh
#Submit to the queue
#Note if the number of jobs is large, you will receive an e-mail for start/stop/fail for each job
#3) Example submission loop
#for i in {0..9}; do; qsub pbs.starscript.$i; sleep 1; done

#Build up a space sep'd array of sample/file prefix
declare -a SAMPLE=(TCGA_UCEC_NA1CI TCGA_UCEC_A1CI)

#set a tmpdir for parallel
tmpdir=`pwd`

#Adjust the length of the array to iterate over to match the number of samples/files to analyze
for i in {0..1}; do
    cat > pbs.biscuitscript.$i << EOF

#PBS -l walltime=120:00:00
#PBS -l mem=200gb
#PBS -l nodes=1:ppn=40
#PBS -M ben.johnson@vai.org
#PBS -m abe
#PBS -N align

#Change to WGBS directory
cd /secondary/projects/triche/ben_projects/biscuit_manuscript/analysis/biscuit_tcga_ucec

#these are directional libs
#Launch biscuit
biscuit align -M -R '@RG\tLB:hg38\tID:WGBS_${SAMPLE[i]}\tPL:Illumina\tPU:hiseq2000\tSM:${SAMPLE[i]}' \
-t 40 -b 1 \
/secondary/projects/triche/ben_projects/references/human/hg38/indexes/biscuit_gencode/hg38_PA \
${SAMPLE[i]}.pe1.fq.gz ${SAMPLE[i]}.pe2.fq.gz | \
samblaster -M --addMateTags | parallel --tmpdir ${tmpdir} --pipe --tee {} ::: 'samblaster -M -a -e -u ${SAMPLE[i]}.clipped.fastq -d ${SAMPLE[i]}.disc.hg38.sam -s ${SAMPLE[i]}.split.hg38.sam -o /dev/null' \
'samtools view -hb | samtools sort -@ 8 -m 5G -o ${SAMPLE[i]}.sorted.markdup.withdisc_split_clip.hg38.bam -O BAM -'

#you can collect the split and discordant bams out of smoove too

#sort and convert to bams
samtools sort -o ${SAMPLE[i]}.disc.hg38.bam -O BAM ${SAMPLE[i]}.disc.hg38.sam
#index
samtools index ${SAMPLE[i]}.disc.hg38.bam

#sort and convert to bams
samtools sort -o ${SAMPLE[i]}.split.hg38.bam -O BAM ${SAMPLE[i]}.split.hg38.sam
#index
samtools index ${SAMPLE[i]}.split.hg38.bam

#compress
pigz -p 40 ${SAMPLE[i]}.clipped.fastq

#index the full bam
samtools index ${SAMPLE[i]}.sorted.markdup.withdisc_split_clip.hg38.bam

#clean up the sams...
if [[ -f ${SAMPLE[i]}.disc.hg38.bam ]] && [[ -f ${SAMPLE[i]}.split.hg38.bam ]]; then rm *.sam; fi

EOF
done
