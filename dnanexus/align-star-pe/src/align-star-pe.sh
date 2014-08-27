#!/bin/bash
# align-star-se 0.0.1
# Generated by dx-app-wizard.
#
# Basic execution pattern: Your app will run on a single machine from
# beginning to end.
#
# Your job's input variables (if any) will be loaded as environment
# variables before this script runs.  Any array inputs will be loaded
# as bash arrays.
#
# Any code outside of main() (or any entry point you may add) is
# ALWAYS executed, followed by running the entry point itself.
#
# See https://wiki.dnanexus.com/Developer-Portal for tutorials on how
# to modify this file.

main() {

    echo "Value of reads: '$reads_1'"
    echo "Value of reads: '$reads_2'"
    echo "Value of star_index: '$star_index'"
    echo "Value of library_id: '$library_id'"

    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".

    echo "Download files"
    reads1_fn=`dx describe "$reads_1" --name | cut -d'.' -f1`
    dx download "$reads_1" -o "$reads1_fn".fastq.gz
    reads2_fn=`dx describe "$reads_2" --name | cut -d'.' -f1`
    dx download "$reads_2" -o "$reads2_fn".fastq.gz
   #gunzip "$reads_fn".fastq.gz

    dx download "$star_index" -o star_index.tgz
    tar zxvf star_index.tgz

    # unzips into "out/"

    # Fill in your application code here.
    #
    # To report any recognized errors in the correct format in
    # $HOME/job_error.json and exit this script, you can use the
    # dx-jobutil-report-error utility as follows:
    #
    #   dx-jobutil-report-error "My error message"
    #
    # Note however that this entire bash script is executed with -e
    # when running in the cloud, so any line which returns a nonzero
    # exit code will prematurely exit the script; if no error was
    # reported in the job_error.json file, then the failure reason
    # will be AppInternalError with a generic error message.
    echo "set up headers"
    libraryComment="@CO\tLIBID:${library_id}"
    echo -e ${libraryComment} > COfile.txt
    cat out/*_bamCommentLines.txt >> COfile.txt

    echo `cat COfile.txt`

    echo "dowload and install STAR"
    git clone https://github.com/alexdobin/STAR
    (cd STAR; git checkout tags/STAR_2.4.0a)
    (cd STAR; make)

    echo "map reads"
    STAR/STAR --genomeDir out --readFilesIn ${reads1_fn}.fastq.gz ${reads2_fn}.fastq.gz \
         --readFilesCommand zcat --runThreadN 8 --genomeLoad NoSharedMemory          \
         --outFilterMultimapNmax 20 --alignSJoverhangMin 8 --alignSJDBoverhangMin 1    \
         --outFilterMismatchNmax 999 --outFilterMismatchNoverReadLmax 0.04              \
         --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000         \
         --outSAMheaderCommentFile COfile.txt --outSAMheaderHD @HD VN:1.4 SO:coordinate   \
         --outSAMunmapped Within --outFilterType BySJout --outSAMattributes NH HI AS NM MD \
         --outWigType bedGraph --outWigStrand Stranded     \
         --outSAMtype BAM SortedByCoordinate --quantMode TranscriptomeSAM

    echo "index bam"
    samtools index Aligned.sortedByCoord.out.bam
    echo `ls`

    echo "Convert bedGraph to bigWigs.  Spike-ins must be excluded and piping doesn't work"
    grep ^chr Signal.UniqueMultiple.str1.out.bg > signalAllMinus.bg
    /usr/bin/bedGraphToBigWig signalAllMinus.bg out/chrNameLength.txt    ${reads1_fn}-${reads2_fn}_STAR_signal_minus_All.bw
    grep ^chr Signal.Unique.str1.out.bg         > signalUniqMinus.bg
    /usr/bin/bedGraphToBigWig signalUniqMinus.bg out/chrNameLength.txt   ${reads1_fn}-${reads2_fn}_STAR_signal_minus_Uniq.bw

    grep ^chr Signal.UniqueMultiple.str2.out.bg > signalAllPlus.bg
    /usr/bin/bedGraphToBigWig signalAllPlus.bg out/chrNameLength.txt    ${reads1_fn}-${reads2_fn}_STAR_signal_plus_All.bw
    grep ^chr Signal.Unique.str2.out.bg         > signalUniqPlus.bg
    /usr/bin/bedGraphToBigWig signalUniqPlus.bg out/chrNameLength.txt   ${reads1_fn}-${reads2_fn}_STAR_signal_plus_Uniq.bw
    # The following line(s) use the dx command-line tool to upload your file
    # outputs after you have created them on the local file system.  It assumes
    # that you have used the output field name for the filename for each output,
    # but you can change that behavior to suit your needs.  Run "dx upload -h"
    # to see more options to set metadata.
    echo `ls`

    mv Aligned.sortedByCoord.out.bam ${reads1_fn}-${reads2_fn}_STAR_genome.bam
    mv Aligned.sortedByCoord.out.bam.bai ${reads1_fn}-${reads2_fn}_STAR_genome.bai
    mv Aligned.toTranscriptome.out.bam ${reads1_fn}-${reads2_fn}_STAR_annotation.bam
    mv Log.final.out ${reads1_fn}-${reads2_fn}_STAR_Log.final.out

    star_log=$(dx upload ${reads1_fn}-${reads2_fn}_STAR_Log.final.out --brief)
    genome_bam=$(dx upload ${reads1_fn}-${reads2_fn}_STAR_genome.bam --brief)
    genome_bai=$(dx upload ${reads1_fn}-${reads2_fn}_STAR_genome.bai --brief)
    annotation_bam=$(dx upload ${reads1_fn}-${reads2_fn}_STAR_annotation.bam --brief)
    all_minus_bw=$(dx upload ${reads1_fn}-${reads2_fn}_STAR_signal_minus_All.bw --brief)
    unique_minus_bw=$(dx upload ${reads1_fn}-${reads2_fn}_STAR_signal_minus_Uniq.bw --brief)
    all_plus_bw=$(dx upload ${reads1_fn}-${reads2_fn}_STAR_signal_plus_All.bw --brief)
    unique_plus_bw=$(dx upload ${reads1_fn}-${reads2_fn}_STAR_signal_plus_Uniq.bw --brief)

    # The following line(s) use the utility dx-jobutil-add-output to format and
    # add output variables to your job's output as appropriate for the output
    # class.  Run "dx-jobutil-add-output -h" for more information on what it
    # does.

    dx-jobutil-add-output star_log "$star_log" --class=file
    dx-jobutil-add-output genome_bam "$genome_bam" --class=file
    dx-jobutil-add-output genome_bai "$genome_bai" --class=file
    dx-jobutil-add-output annotation_bam "$annotation_bam" --class=file
    dx-jobutil-add-output all_minus_bw "$all_minus_bw" --class=file
    dx-jobutil-add-output unique_minus_bw "$unique_minus_bw" --class=file
    dx-jobutil-add-output all_plus_bw "$all_plus_bw" --class=file
    dx-jobutil-add-output unique_plus_bw "$unique_plus_bw" --class=file
}
