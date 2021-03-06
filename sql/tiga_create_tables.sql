CREATE TABLE gwas (
	date_added_to_catalog DATE,
	pubmedid VARCHAR(32),
	first_author VARCHAR(32),
	date DATE,
	journal VARCHAR(128),
	link VARCHAR(128),
	study VARCHAR(512),
	disease_trait VARCHAR(512),
	initial_sample_size VARCHAR(16),
	replication_sample_size VARCHAR(16),
	platform_snps_passing_qc VARCHAR(64),
	association_count INT,
	mapped_trait VARCHAR(512),
	mapped_trait_uri VARCHAR(128),
	study_accession VARCHAR(16),
	genotyping_technology VARCHAR(512)
);
CREATE TABLE assn (
	date_added_to_catalog DATE,
	pubmedid VARCHAR(32),
	first_author VARCHAR(32),
	date DATE,
	journal VARCHAR(128),
	link VARCHAR(128),
	study VARCHAR(512),
	disease_trait VARCHAR(512),
	initial_sample_size VARCHAR(16),
	replication_sample_size VARCHAR(16),
	region VARCHAR(16),
	chr_id VARCHAR(8),
	chr_pos VARCHAR(16),
	reported_genes VARCHAR(512),
	mapped_gene VARCHAR(32),
	upstream_gene_id VARCHAR(12),
	downstream_gene_id VARCHAR(12),
	snp_gene_ids VARCHAR(512),
	upstream_gene_distance INT,
	downstream_gene_distance INT,
	strongest_snp_risk_allele VARCHAR(16),
	snps VARCHAR(16),
	merged CHAR(1),
	snp_id_current VARCHAR(16),
	context VARCHAR(32),
	intergenic CHAR(1),
	risk_allele_frequency FLOAT,
	p_value FLOAT,
	pvalue_mlog FLOAT,
	p_value_text VARCHAR(32),
	or_or_beta FLOAT,
	ci_95_text VARCHAR(32),
	platform_snps_passing_qc VARCHAR(64),
	cnv CHAR(1),
	mapped_trait VARCHAR(512),
	mapped_trait_uri VARCHAR(128),
	study_accession VARCHAR(16),
	genotyping_technology VARCHAR(512),
	oddsratio FLOAT,
	beta FLOAT
);
CREATE TABLE snp2gene (
	study_accession VARCHAR(16),
	snp VARCHAR(32),
	gsymb VARCHAR(16),
	ensg VARCHAR(32),
	reported_or_mapped VARCHAR(4)
);
CREATE TABLE trait2study (
	study_accession VARCHAR(16),
	mapped_trait VARCHAR(512),
	mapped_trait_uri VARCHAR(128),
	id VARCHAR(16),
	efo_label VARCHAR(512)
);
CREATE TABLE icite (
	authors MEDIUMTEXT,
	citation_count INT,
	citations_per_year FLOAT,
	doi VARCHAR(64),
	expected_citations_per_year FLOAT,
	field_citation_rate FLOAT,
	is_research_article BOOLEAN,
	journal VARCHAR(128),
	nih_percentile FLOAT,
	pmid INT,
	relative_citation_ratio FLOAT,
	title MEDIUMTEXT,
	year INT
);
CREATE TABLE gt_stats (
	ensemblId VARCHAR(16),
	efoId VARCHAR(16),
	trait VARCHAR(512),
	n_study INT,
	n_snp INT,
	n_snpw FLOAT,
	geneNtrait INT,
	traitNgene INT,
	traitNstudy INT,
	pvalue_mlog_median FLOAT,
	or_median FLOAT,
	study_N_mean INT,
	rcras FLOAT,
	geneSymbol VARCHAR(16),
	geneIdgTdl VARCHAR(8),
	geneFamily VARCHAR(16),
	geneIdgList BOOLEAN,
	geneName VARCHAR(128),
	muScore FLOAT,
	muRank INT
);
