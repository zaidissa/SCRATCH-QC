process EXTRACT_UNMAPPED {

    tag "Extract unmapped reads"
    label 'process_high'

    executor = 'local'

    container "syedsazaidi/scratch-microbiome:latest"

    input:
        path(bam_file)

    output:
        path("unmapped.bam")

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        samtools view -b -f 4 $bam_file > unmapped.bam
        """

    stub:
        """
        touch unmapped.bam
        """
}

process BAM_TO_FASTQ {

    tag "Convert BAM to FASTQ"
    label 'process_high'

    executor = 'local'

    container "syedsazaidi/scratch-microbiome:latest"

    input:
        path(bam_file)

    output:
        tuple path("unmapped_R1.fastq"), path("unmapped_R2.fastq")

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        bedtools bamtofastq -i $bam_file -fq unmapped_R1.fastq -fq2 unmapped_R2.fastq
        """

    stub:
        """
        touch unmapped_R1.fastq
        touch unmapped_R2.fastq
        """
}

process FILTER_HUMAN_READS {

    tag "Remove human reads"
    label 'process_high'

    executor = 'local'

    container "syedsazaidi/scratch-microbiome:latest"

    input:
        tuple path(r1), path(r2)

    output:
        tuple path("filtered_R1.fastq"), path("filtered_R2.fastq")

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        bowtie2 -p 16 --un-conc filtered_%.fastq -x /path/to/human_genome -1 $r1 -2 $r2
        """

    stub:
        """
        touch filtered_R1.fastq
        touch filtered_R2.fastq
        """
}

process CLASSIFY_MICROBIOME {

    tag "Classify microbiome reads with KrakenUniq"
    label 'process_high'

    executor = 'local'

    container "syedsazaidi/scratch-microbiome:latest"

    input:
        tuple path(r1), path(r2)

    output:
        path("krakenuniq_report.txt"), emit: krakenuniq_report
        path("krakenuniq_output.tsv"), emit: krakenuniq_output

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        krakenuniq --db /path/to/krakenuniq_db --paired $r1 $r2 \
            --report-file krakenuniq_report.txt \
            --output krakenuniq_output.tsv
        """

    stub:
        """
        touch krakenuniq_report.txt
        touch krakenuniq_output.tsv
        """
}

process REFINE_CLASSIFICATION_BRACKEN {

    tag "Refine classification with Bracken"
    label 'process_high'

    executor = 'local'

    container "syedsazaidi/scratch-microbiome:latest"

    input:
        path krakenuniq_report

    output:
        path("bracken_output.tsv"), emit: bracken_output

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        bracken -d /path/to/krakenuniq_db -i $krakenuniq_report -o bracken_output.tsv -l S
        """

    stub:
        """
        touch bracken_output.tsv
        """
}

process SPECIES_PROFILING_METAPHLAN {

    tag "Species-level profiling with MetaPhlAn"
    label 'process_high'

    executor = 'local'

    container "syedsazaidi/scratch-microbiome:latest"

    input:
        tuple path(r1), path(r2)

    output:
        path("metaphlan_output.txt"), emit: metaphlan_output

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        metaphlan $r1,$r2 --input_type fastq --nproc 16 --bowtie2out sample.bowtie2.bz2 -o metaphlan_output.txt
        """

    stub:
        """
        touch metaphlan_output.txt
        """
}

process LINK_MICROBES_TO_CELLS {

    tag "Map microbial reads to single-cell barcodes"
    label 'process_high'

    executor = 'local'

    container "syedsazaidi/scratch-microbiome:latest"

    input:
        path bam_file

    output:
        path("cell_barcode_counts.txt"), emit: cell_microbe_counts

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        samtools view $bam_file | awk '{print \$1}' | sort | uniq -c > cell_barcode_counts.txt
        """

    stub:
        """
        touch cell_barcode_counts.txt
        """
}

process GENERATE_CELLWISE_PROFILE {

    tag "Generate per-cell microbiome profile"
    label 'process_high'

    executor = 'local'

    container "syedsazaidi/scratch-microbiome:latest"

    input:
        path cell_microbe_counts

    output:
        path("cell_microbiome_profile.tsv"), emit: cell_profile

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        umi_tools count --per-cell --per-gene -I cell_microbe_counts.txt -S cell_microbiome_profile.tsv
        """

    stub:
        """
        touch cell_microbiome_profile.tsv
        """
}