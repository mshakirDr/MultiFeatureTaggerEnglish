#!/usr/bin/perl
# -*-cperl-*-

## Multi-Feature Tagger of English (MFTE) by Elen Le Foll (ELF) - For tagging a range of lexico-grammatical features and counting the tags (suitable for full multi-dimensional analyses; MDAs).

## Originally based on a cross-platform version of Andrea Nini's Multidimensional Analysis Tagger (MAT) which is, itself, an open-source replication of the Biber Tagger (1988)

## This code was formally evaluated on perl 5, version 22, subversion 1 (v5.22.1) built for x86_64-linux-gnu-thread-multi 
## It was additionally tested on perl 5, version 30, subversion 2 (v5.30.2) built for darwin-thread-multi-2level

$| = 1;

use FindBin qw($RealBin);
use File::Temp;
use File::Slurp;
#use Gzip::Faster;

# The following four lines were kindly contributed by Peter Uhrig (see also line 1355)
use utf8;
use open OUT => ':encoding(UTF-8)';
use open IN => ':encoding(UTF-8)';
use open IO => ':encoding(UTF-8)';

die <<EOT unless @ARGV == 3 || @ARGV == 4;

Multi-Feature Tagger of English (MFTE) v. 3.0

***

Please cite as: 
Le Foll, Elen (2021). A Multi-Feature Tagger of English (MFTE). Software v. 3.0. 
Available under a GPL-3.0 License on: https://github.com/elenlefoll/MultiFeatureTaggerEnglish

Code based on the Multidimensional Analysis Tagger v. 1.3 by Andrea Nini [https://sites.google.com/site/multidimensionaltagger/]:
Nini, Andrea (2019). The Muli-Dimensional Analysis Tagger. In Berber Sardinha, T. & Veirano Pinto M. (eds), Multi-Dimensional Analysis: Research Methods and Current Issues, 67-94, London; New York: Bloomsbury Academic. 

Requires the separate installation of the Stanford Tagger for English [http://nlp.stanford.edu/software/tagger.shtml]:
Kristina Toutanova, Dan Klein, Christopher Manning, & Yoram Singer (2003). Feature-Rich Part-of-Speech Tagging with a Cyclic Dependency Network. In Proceedings of HLT-NAACL 2003: pp. 252-259. 

***

Installation:

See readme: https://github.com/elenlefoll/MultiFeatureTaggerEnglish

Usage:

Navigate to the folder with the MFTE and the Stanford Tagger and run the MFTE_3.0.pl perl script from a terminal with the following command:

perl MFTE_3.0.pl input_txt/ tagged_txt/ prefix [TTRsize]

where:

- input_txt stands for the folder (path) containing the text files (in UFT-8) of the corpus to be tagged. Note that the folder input_txt must contain the corpus texts as separate files in plain text format (.txt) and UTF-8 encoding. All files in the folder will be processed, regardless of their extension.
- tagged_txt stands for the folder (path) to be created by the programme to place the tagged text files.
- prefix stands for the prefix of the names of the three tables that will be output by the programme (see below).
- [TTRsize] is an optional parameter that defines how many words are used to calculate the type/token ratio (TTR) variable. It should be less than the shortest text in the corpus. If no value is entered the default is 400, as in Biber (1988).

Note that this script only tags and computes a count tally of all the features. It does not compute any dimensions. See corresponding .Rmd file in GitHub repository to do so.

Detailed documentation available on: https://github.com/elenlefoll/MultiFeatureTaggerEnglish

EOT

our ($InputDir, $OutputDir, $Prefix, $TokensForTTR, $NormBasis) = @ARGV;
$TokensForTTR = 400 unless $TokensForTTR;
$NormBasis = 1 unless $NormBasis;

my $directory_MAT = "$OutputDir/MD";

unless (-d $OutputDir) {
  mkdir $OutputDir or die "Can't create output directory $OutputDir/: $!";
}
die "Error: $OutputDir exists but isn't a directory\n" unless -d $OutputDir;

unless (-d $directory_MAT) {
  mkdir $directory_MAT or die "Can't create output directory $directory_MAT/: $!";
}
die "Error: $directory_MAT exists but isn't a directory\n" unless -d $directory_MAT;

#run_tagger($InputDir, $OutputDir, $directory_MAT);
do_counts($Prefix, $directory_MAT, $TokensForTTR);

print "Feature tagging and counting complete. Share and enjoy!\n";

############################################################
#run ST and MAT taggers and save files
sub run_tagger {
  my ($input_dir, $tagged_dir, $directory_MAT) = @_;


  opendir(DIR, $input_dir) or die "Can't read directory $input_dir/: $!";
  my @filenames = grep {-f "$input_dir/$_"} readdir(DIR);
  close(DIR);
  
  ## @filenames = @filenames[0 .. 99] if (@filenames > 100); # for TESTING
  my $n_files = @filenames;
  #stanford tagger on files and save   
  # foreach my $n (0 .. $n_files - 1) {
  #   $command = "java -mx5000m -cp 'StanfordTagger/stanford-postagger.jar' edu.stanford.nlp.tagger.maxent.MaxentTagger -model 'StanfordTagger/models/english-bidirectional-distsim.tagger' -textFile \"$input_dir/$filenames[$n]\" >  \"$tagged_dir/$filenames[$n]\"";
  #   print STDERR "Processing file $input_dir/$filenames[$n]\n";
  #   system("$command")
  # }

  #run MAT post processing
  opendir(DIR, $tagged_dir) or die "Can't read directory $tagged_dir/: $!";
  my @filenames = grep {-f "$tagged_dir/$_"} readdir(DIR);
  close(DIR);
  my $n_files = @filenames;
  foreach my $n (0 .. $n_files - 1) {
    print STDERR "MD Tagger processing file $tagged_dir/$filenames[$n]\n";
    my $file_open = "$tagged_dir/$filenames[$n]";
    my $file_content = read_file($file_open);
    my @sentences_tagged = ();
    #print $file_content;
    my @sentences = split("[\r\n]+", $file_content); #Shakir: split on new lines for sentences
    #$"=", "; 
    #print "The sentences are: @sentences\n";
    for my $sentence (@sentences) { #loop over each sentence
      if ($sentence ne ""){
        my @words = split(/ +/, $sentence); #split on space (words)
        if (@words > 0) {
        my @tagged = process_sentence(@words);
        push @sentences_tagged, @tagged; #add tagged words to main array
        }
      }
    }
      #$"=", "; 
      #print "The all tagged words are: @tagged\n";
    my $text_tagged = join("\n", @sentences_tagged);
    my $tagged_filename = "$directory_MAT/$filenames[$n]";
    write_file($tagged_filename, $text_tagged);
  }
}

############################################################
## Post-process tagged sentences (as lists of words)

sub process_sentence {
  my @word = @_;

  # DICTIONARY LISTS
  
  $have = "have_V|has_V|ve_V|had_V|having_V|hath_|s_VBZ|d_V"; # ELF: added s_VBZ, added d_VBD, e.g. "he's got, he's been and he'd been" ELF: Also removed all the apostrophes in Nini's lists because they don't work in combination with \b in regex as used extensively in this script.
 
  $do ="do_V|does_V|did_V|done_V|doing_V|doing_P|done_P"; 
 
  $be = "be_V|am_V|is_V|are_V|was_V|were_V|been_V|being_V|s_VBZ|m_V|re_V|been_P"; # ELF: removed apostrophes and added "been_P" to account for the verb "be" when tagged as occurrences of passive or perfect forms (PASS and PEAS tags).
 
  $who = "what_|where_|when_|how_|whether_|why_|whoever_|whomever_|whichever_|wherever_|whenever_|whatever_"; # ELF: Removed "however" from Nini/Biber's original list.
 
  $wp = "who_|whom_|whose_|which_";
 
  # ELF: added this list for new WH-question variable:  
  $whw = "what_|where_|when_|how_|why_|who_|whom_|whose_|which_"; 
 
  $preposition = "about_|against_|amid_|amidst_|among_|amongst_|at_|between_|by_|despite_|during_|except_|for_|from_|in_|into_|minus_|of_|off_|on_|onto_|opposite_|out_|per_|plus_|pro_|than_|through_|throughout_|thru_|toward_|towards_|upon_|versus_|via_|with_|within_|without_"; # ELF: removed "besides".
  
  # ELF: Added this new list but it currently not in use.
  #$particles =
#"about|above|across|ahead|along|apart|around|aside|at|away|back|behind|between|by|down|forward|from|in|into|off|on|out|over|past|through|to|together|under|up|upon|with|without"; 

  # ELF: The next three lists of semantic categories of verbs are taken from Biber 1988; however, the current version of the script uses the verb semantic categories from Biber 2006 instead, but the following three lists are still used for some variables, e.g. THATD.
  $public = "acknowledge_V|acknowledged_V|acknowledges_V|acknowledging_V|add_V|adds_V|adding_V|added_V|admit_V|admits_V|admitting_V|admitted_V|affirm_V|affirms_V|affirming_V|affirmed_V|agree_V|agrees_V|agreeing_V|agreed_V|allege_V|alleges_V|alleging_V|alleged_V|announce_V|announces_V|announcing_V|announced_V|argue_V|argues_V|arguing_V|argued_V|assert_V|asserts_V|asserting_V|asserted_V|bet_V|bets_V|betting_V|boast_V|boasts_V|boasting_V|boasted_V|certify_V|certifies_V|certifying_V|certified_V|claim_V|claims_V|claiming_V|claimed_V|comment_V|comments_V|commenting_V|commented_V|complain_V|complains_V|complaining_V|complained_V|concede_V|concedes_V|conceding_V|conceded_V|confess_V|confesses_V|confessing_V|confessed_V|confide_V|confides_V|confiding_V|confided_V|confirm_V|confirms_V|confirming_V|confirmed_V|contend_V|contends_V|contending_V|contended_V|convey_V|conveys_V|conveying_V|conveyed_V|declare_V|declares_V|declaring_V|declared_V|deny_V|denies_V|denying_V|denied_V|disclose_V|discloses_V|disclosing_V|disclosed_V|exclaim_V|exclaims_V|exclaiming_V|exclaimed_V|explain_V|explains_V|explaining_V|explained_V|forecast_V|forecasts_V|forecasting_V|forecasted_V|foretell_V|foretells_V|foretelling_V|foretold_V|guarantee_V|guarantees_V|guaranteeing_V|guaranteed_V|hint_V|hints_V|hinting_V|hinted_V|insist_V|insists_V|insisting_V|insisted_V|maintain_V|maintains_V|maintaining_V|maintained_V|mention_V|mentions_V|mentioning_V|mentioned_V|object_V|objects_V|objecting_V|objected_V|predict_V|predicts_V|predicting_V|predicted_V|proclaim_V|proclaims_V|proclaiming_V|proclaimed_V|promise_V|promises_V|promising_V|promised_V|pronounce_V|pronounces_V|pronouncing_V|pronounced_V|prophesy_V|prophesies_V|prophesying_V|prophesied_V|protest_V|protests_V|protesting_V|protested_V|remark_V|remarks_V|remarking_V|remarked_V|repeat_V|repeats_V|repeating_V|repeated_V|reply_V|replies_V|replying_V|replied_V|report_V|reports_V|reporting_V|reported_V|say_V|says_V|saying_V|said_V|state_V|states_V|stating_V|stated_V|submit_V|submits_V|submitting_V|submitted_V|suggest_V|suggests_V|suggesting_V|suggested_V|swear_V|swears_V|swearing_V|swore_V|sworn_V|testify_V|testifies_V|testifying_V|testified_V|vow_V|vows_V|vowing_V|vowed_V|warn_V|warns_V|warning_V|warned_V|write_V|writes_V|writing_V|wrote_V|written_V";
  $private = "accept_V|accepts_V|accepting_V|accepted_V|anticipate_V|anticipates_V|anticipating_V|anticipated_V|ascertain_V|ascertains_V|ascertaining_V|ascertained_V|assume_V|assumes_V|assuming_V|assumed_V|believe_V|believes_V|believing_V|believed_V|calculate_V|calculates_V|calculating_V|calculated_V|check_V|checks_V|checking_V|checked_V|conclude_V|concludes_V|concluding_V|concluded_V|conjecture_V|conjectures_V|conjecturing_V|conjectured_V|consider_V|considers_V|considering_V|considered_V|decide_V|decides_V|deciding_V|decided_V|deduce_V|deduces_V|deducing_V|deduced_V|deem_V|deems_V|deeming_V|deemed_V|demonstrate_V|demonstrates_V|demonstrating_V|demonstrated_V|determine_V|determines_V|determining_V|determined_V|discern_V|discerns_V|discerning_V|discerned_V|discover_V|discovers_V|discovering_V|discovered_V|doubt_V|doubts_V|doubting_V|doubted_V|dream_V|dreams_V|dreaming_V|dreamt_V|dreamed_V|ensure_V|ensures_V|ensuring_V|ensured_V|establish_V|establishes_V|establishing_V|established_V|estimate_V|estimates_V|estimating_V|estimated_V|expect_V|expects_V|expecting_V|expected_V|fancy_V|fancies_V|fancying_V|fancied_V|fear_V|fears_V|fearing_V|feared_V|feel_V|feels_V|feeling_V|felt_V|find_V|finds_V|finding_V|found_V|foresee_V|foresees_V|foreseeing_V|foresaw_V|forget_V|forgets_V|forgetting_V|forgot_V|forgotten_V|gather_V|gathers_V|gathering_V|gathered_V|guess_V|guesses_V|guessing_V|guessed_V|hear_V|hears_V|hearing_V|heard_V|hold_V|holds_V|holding_V|held_V|hope_V|hopes_V|hoping_V|hoped_V|imagine_V|imagines_V|imagining_V|imagined_V|imply_V|implies_V|implying_V|implied_V|indicate_V|indicates_V|indicating_V|indicated_V|infer_V|infers_V|inferring_V|inferred_V|insure_V|insures_V|insuring_V|insured_V|judge_V|judges_V|judging_V|judged_V|know_V|knows_V|knowing_V|knew_V|known_V|learn_V|learns_V|learning_V|learnt_V|learned_V|mean_V|means_V|meaning_V|meant_V|note_V|notes_V|noting_V|noted_V|notice_V|notices_V|noticing_V|noticed_V|observe_V|observes_V|observing_V|observed_V|perceive_V|perceives_V|perceiving_V|perceived_V|presume_V|presumes_V|presuming_V|presumed_V|presuppose_V|presupposes_V|presupposing_V|presupposed_V|pretend_V|pretend_V|pretending_V|pretended_V|prove_V|proves_V|proving_V|proved_V|realize_V|realise_V|realising_V|realizing_V|realises_V|realizes_V|realised_V|realized_V|reason_V|reasons_V|reasoning_V|reasoned_V|recall_V|recalls_V|recalling_V|recalled_V|reckon_V|reckons_V|reckoning_V|reckoned_V|recognize_V|recognise_V|recognizes_V|recognises_V|recognizing_V|recognising_V|recognized_V|recognised_V|reflect_V|reflects_V|reflecting_V|reflected_V|remember_V|remembers_V|remembering_V|remembered_V|reveal_V|reveals_V|revealing_V|revealed_V|see_V|sees_V|seeing_V|saw_V|seen_V|sense_V|senses_V|sensing_V|sensed_V|show_V|shows_V|showing_V|showed_V|shown_V|signify_V|signifies_V|signifying_V|signified_V|suppose_V|supposes_V|supposing_V|supposed_V|suspect_V|suspects_V|suspecting_V|suspected_V|think_V|thinks_V|thinking_V|thought_V|understand_V|understands_V|understanding_V|understood_V";
  $suasive = "agree_V|agrees_V|agreeing_V|agreed_V|allow_V|allows_V|allowing_V|allowed_V|arrange_V|arranges_V|arranging_V|arranged_V|ask_V|asks_V|asking_V|asked_V|beg_V|begs_V|begging_V|begged_V|command_V|commands_V|commanding_V|commanded_V|concede_V|concedes_V|conceding_V|conceded_V|decide_V|decides_V|deciding_V|decided_V|decree_V|decrees_V|decreeing_V|decreed_V|demand_V|demands_V|demanding_V|demanded_V|desire_V|desires_V|desiring_V|desired_V|determine_V|determines_V|determining_V|determined_V|enjoin_V|enjoins_V|enjoining_V|enjoined_V|ensure_V|ensures_V|ensuring_V|ensured_V|entreat_V|entreats_V|entreating_V|entreated_V|grant_V|grants_V|granting_V|granted_V|insist_V|insists_V|insisting_V|insisted_V|instruct_V|instructs_V|instructing_V|instructed_V|intend_V|intends_V|intending_V|intended_V|move_V|moves_V|moving_V|moved_V|ordain_V|ordains_V|ordaining_V|ordained_V|order_V|orders_V|ordering_V|ordered_V|pledge_V|pledges_V|pledging_V|pledged_V|pray_V|prays_V|praying_V|prayed_V|prefer_V|prefers_V|preferring_V|preferred_V|pronounce_V|pronounces_V|pronouncing_V|pronounced_V|propose_V|proposes_V|proposing_V|proposed_V|recommend_V|recommends_V|recommending_V|recommended_V|request_V|requests_V|requesting_V|requested_V|require_V|requires_V|requiring_V|required_V|resolve_V|resolves_V|resolving_V|resolved_V|rule_V|rules_V|ruling_V|ruled_V|stipulate_V|stipulates_V|stipulating_V|stipulated_V|suggest_V|suggests_V|suggesting_V|suggested_V|urge_V|urges_V|urging_V|urged_V|vote_V|votes_V|voting_V|voted_V";
  
  # The following lists are based on the verb semantic categories used in Biber 2006.
  # ELF: With many thanks to Muhammad Shakir for providing me with these lists.
  
  # Activity verbs 
  # ELF: removed GET and GO due to high polysemy and corrected the "evercise" typo found in both Shakir and Biber 2006.
  $vb_act =	"(buy|buys|buying|bought|make|makes|making|made|give|gives|giving|gave|given|take|takes|taking|took|taken|come|comes|coming|came|use|uses|using|used|leave|leaves|leaving|left|show|shows|showing|showed|shown|try|tries|trying|tried|work|works|wrought|worked|working|move|moves|moving|moved|follow|follows|following|followed|put|puts|putting|pay|pays|paying|paid|bring|brings|bringing|brought|meet|meets|met|play|plays|playing|played|run|runs|running|ran|hold|holds|holding|held|turn|turns|turning|turned|send|sends|sending|sent|sit|sits|sitting|sat|wait|waits|waiting|waited|walk|walks|walking|walked|carry|carries|carrying|carried|lose|loses|losing|lost|eat|eats|ate|eaten|eating|watch|watches|watching|watched|reach|reaches|reaching|reached|add|adds|adding|added|produce|produces|producing|produced|provide|provides|providing|provided|pick|picks|picking|picked|wear|wears|wearing|wore|worn|open|opens|opening|opened|win|wins|winning|won|catch|catches|catching|caught|pass|passes|passing|passed|shake|shakes|shaking|shook|shaken|smile|smiles|smiling|smiled|stare|stares|staring|stared|sell|sells|selling|sold|spend|spends|spending|spent|apply|applies|applying|applied|form|forms|forming|formed|obtain|obtains|obtaining|obtained|arrange|arranges|arranging|arranged|beat|beats|beating|beaten|check|checks|checking|checked|cover|covers|covering|covered|divide|divides|dividing|divided|earn|earns|earning|earned|extend|extends|extending|extended|fix|fixes|fixing|fixed|hang|hangs|hanging|hanged|hung|join|joins|joining|joined|lie|lies|lying|lay|lain|lied|obtain|obtains|obtaining|obtained|pull|pulls|pulling|pulled|repeat|repeats|repeating|repeated|receive|receives|receiving|received|save|saves|saving|saved|share|shares|sharing|shared|smile|smiles|smiling|smiled|throw|throws|throwing|threw|thrown|visit|visits|visiting|visited|accompany|accompanies|accompanying|accompanied|acquire|acquires|acquiring|acquired|advance|advances|advancing|advanced|behave|behaves|behaving|behaved|borrow|borrows|borrowing|borrowed|burn|burns|burning|burned|burnt|clean|cleaner|cleanest|cleans|cleaning|cleaned|climb|climbs|climbing|climbed|combine|combines|combining|combined|control|controls|controlling|controlled|defend|defends|defending|defended|deliver|delivers|delivering|delivered|dig|digs|digging|dug|encounter|encounters|encountering|encountered|engage|engages|engaging|engaged|exercise|exercised|exercising|exercises|expand|expands|expanding|expanded|explore|explores|exploring|explored|reduce|reduces|reducing|reduced)";
  
  # Communication verbs 
  # ELF: corrected a typo for "descibe" and added its other forms, removed "spake" as a form of SPEAK, removed some adjective forms like "fitter, fittest", etc.
  # In addition, British spellings and the verbs "AGREE, ASSERT, BEG, CONFIDE, COMMAND, DISAGREE, OBJECT, PLEDGE, PRONOUNCE, PLEAD, REPORT, TESTIFY, VOW" (taken from the public and suasive lists above) were added. "MEAN" which was originally assigned to the mental verb list was added to the communication list, instead.
  $vb_comm = "(say|says|saying|said|tell|tells|telling|told|call|calls|calling|called|ask|asks|asking|asked|write|writes|writing|wrote|written|talk|talks|talking|talked|speak|speaks|spoke|spoken|speaking|thank|thanks|thanking|thanked|describe|describing|describes|described|claim|claims|claiming|claimed|offer|offers|offering|offered|admit|admits|admitting|admitted|announce|announces|announcing|announced|answer|answers|answering|answered|argue|argues|arguing|argued|deny|denies|denying|denied|discuss|discusses|discussing|discussed|encourage|encourages|encouraging|encouraged|explain|explains|explaining|explained|express|expresses|expressing|expressed|insist|insists|insisting|insisted|mention|mentions|mentioning|mentioned|offer|offers|offering|offered|propose|proposes|proposing|proposed|quote|quotes|quoting|quoted|reply|replies|replying|replied|shout|shouts|shouting|shouted|sign|signs|signing|signed|sing|sings|singing|sang|sung|state|states|stating|stated|teach|teaches|teaching|taught|warn|warns|warning|warned|accuse|accuses|accusing|accused|acknowledge|acknowledges|acknowledging|acknowledged|address|addresses|addressing|addressed|advise|advises|advising|advised|appeal|appeals|appealing|appealed|assure|assures|assuring|assured|challenge|challenges|challenging|challenged|complain|complains|complaining|complained|consult|consults|consulting|consulted|convince|convinces|convincing|convinced|declare|declares|declaring|declared|demand|demands|demanding|demanded|emphasize|emphasizes|emphasizing|emphasized|emphasise|emphasises|emphasising|emphasised|excuse|excuses|excusing|excused|inform|informs|informing|informed|invite|invites|inviting|invited|persuade|persuades|persuading|persuaded|phone|phones|phoning|phoned|pray|prays|praying|prayed|promise|promises|promising|promised|question|questions|questioning|questioned|recommend|recommends|recommending|recommended|remark|remarks|remarking|remarked|respond|responds|responding|responded|specify|specifies|specifying|specified|swear|swears|swearing|swore|sworn|threaten|threatens|threatening|threatened|urge|urges|urging|urged|welcome|welcomes|welcoming|welcomed|whisper|whispers|whispering|whispered|suggest|suggests|suggesting|suggested|plead|pleads|pleaded|pleading|agree|agrees|agreed|agreeing|assert|asserts|asserting|asserted|beg|begs|begging|begged|confide|confides|confiding|confided|command|commands|commanding|commanded|disagree|disagreeing|disagrees|disagreed|object|objects|objected|objects|pledge|pledges|pledging|pledged|report|reports|reported|reporting|testify|testifies|testified|testifying|vow|vows|vowing|vowed|mean|means|meaning|meant)";
  
  # Mental verbs
  # ELF: Added British spellings, removed AFFORD and FIND. Removed DESERVE which is also on Biber's (2006) existential list. Added wan to account for wanna tokenised as wan na.
  $vb_mental =	"(see|sees|seeing|saw|seen|know|knows|knowing|knew|known|think|thinks|thinking|thought|want|wan|wants|wanting|wanted|need|needs|needing|needed|feel|feels|feeling|felt|like|likes|liking|liked|hear|hears|hearing|heard|remember|remembers|remembering|remembered|believe|believes|believing|believed|read|reads|reading|consider|considers|considering|considered|suppose|supposes|supposing|supposed|listen|listens|listening|listened|love|loves|loving|loved|wonder|wonders|wondering|wondered|understand|understands|understood|expect|expects|expecting|expected|hope|hopes|hoping|hoped|assume|assumes|assuming|assumed|determine|determines|determining|determined|agree|agrees|agreeing|agreed|bear|bears|bearing|bore|borne|care|cares|caring|cared|choose|chooses|choosing|chose|chosen|compare|compares|comparing|compared|decide|decides|deciding|decided|discover|discovers|discovering|discovered|doubt|doubts|doubting|doubted|enjoy|enjoys|enjoying|enjoyed|examine|examines|examining|examined|face|faces|facing|faced|forget|forgets|forgetting|forgot|forgotten|hate|hates|hating|hated|identify|identifies|identifying|identified|imagine|imagines|imagining|imagined|intend|intends|intending|intended|learn|learns|learning|learned|learnt|miss|misses|missing|missed|mind|minds|minding|notice|notices|noticing|noticed|plan|plans|planning|planned|prefer|prefers|preferring|preferred|prove|proves|proving|proved|proven|realize|realizes|realizing|realized|recall|recalls|recalling|recalled|recognize|recognizes|recognizing|recognized|recognise|recognises|recognising|recognised|regard|regards|regarding|regarded|suffer|suffers|suffering|suffered|wish|wishes|wishing|wished|worry|worries|worrying|worried|accept|accepts|accepting|accepted|appreciate|appreciates|appreciating|appreciated|approve|approves|approving|approved|assess|assesses|assessing|assessed|blame|blames|blaming|blamed|bother|bothers|bothering|bothered|calculate|calculates|calculating|calculated|conclude|concludes|concluding|concluded|celebrate|celebrates|celebrating|celebrated|confirm|confirms|confirming|confirmed|count|counts|counting|counted|dare|dares|daring|dared|detect|detects|detecting|detected|dismiss|dismisses|dismissing|dismissed|distinguish|distinguishes|distinguishing|distinguished|experience|experiences|experiencing|experienced|fear|fears|fearing|feared|forgive|forgives|forgiving|forgave|forgiven|guess|guesses|guessing|guessed|ignore|ignores|ignoring|ignored|impress|impresses|impressing|impressed|interpret|interprets|interpreting|interpreted|judge|judges|judging|judged|justify|justifies|justifying|justified|observe|observes|observing|observed|perceive|perceives|perceiving|perceived|predict|predicts|predicting|predicted|pretend|pretends|pretending|pretended|reckon|reckons|reckoning|reckoned|remind|reminds|reminding|reminded|satisfy|satisfies|satisfying|satisfied|solve|solves|solving|solved|study|studies|studying|studied|suspect|suspects|suspecting|suspected|trust|trusts|trusting|trusted)";
  
  # Facilitation or causation verbs
  $vb_cause = "(help|helps|helping|helped|let|lets|letting|allow|allows|allowing|allowed|affect|affects|affecting|affected|cause|causes|causing|caused|enable|enables|enabling|enabled|ensure|ensures|ensuring|ensured|force|forces|forcing|forced|prevent|prevents|preventing|prevented|assist|assists|assisting|assisted|guarantee|guarantees|guaranteeing|guaranteed|influence|influences|influencing|influenced|permit|permits|permitting|permitted|require|requires|requiring|required)";

  # Occurrence verbs
  $vb_occur = "(become|becomes|becoming|became|happen|happens|happening|happened|change|changes|changing|changed|die|dies|dying|died|grow|grows|grew|grown|growing|develop|develops|developing|developed|arise|arises|arising|arose|arisen|emerge|emerges|emerging|emerged|fall|falls|falling|fell|fallen|increase|increases|increasing|increased|last|lasts|lasting|lasted|rise|rises|rising|rose|risen|disappear|disappears|disappearing|disappeared|flow|flows|flowing|flowed|shine|shines|shining|shone|shined|sink|sinks|sank|sunk|sunken|sinking|slip|slips|slipping|slipped|occur|occurs|occurring|occurred)";

  # Existence or relationship verbs ELF: Does not include the copular BE as in Biber (2006). LOOK was also removed due to too high polysemy. 
  $vb_exist =	"(seem|seems|seeming|seemed|stand|stands|standing|stood|stay|stays|staid|stayed|staying|live|lives|living|lived|appear|appears|appearing|appeared|include|includes|including|included|involve|involves|involving|involved|contain|contains|containing|contained|exist|exists|existing|existed|indicate|indicates|indicating|indicated|concern|concerns|concerning|concerned|constitute|constitutes|constituting|constituted|define|defines|defining|defined|derive|derives|deriving|derived|illustrate|illustrates|illustrating|illustrated|imply|implies|implying|implied|lack|lacks|lacking|lacked|owe|owes|owing|owed|own|owns|owning|owned|possess|possesses|possessing|possessed|suit|suits|suiting|suited|vary|varies|varying|varied|fit|fits|fitting|fitted|matter|matters|mattering|mattered|reflect|reflects|reflecting|reflected|relate|relates|relating|related|remain|remains|remaining|remained|reveal|reveals|revealing|revealed|sound|sounds|sounding|sounded|tend|tends|tending|tended|represent|represents|representing|represented|deserve|deserves|deserving|deserved)";

  # Aspectual verbs
  $vb_aspect =	"(start|starts|starting|started|keep|keeps|keeping|kept|stop|stops|stopping|stopped|begin|begins|beginning|began|begun|complete|completes|completing|completed|end|ends|ending|ended|finish|finishes|finishing|finished|cease|ceases|ceasing|ceased|continue|continues|continuing|continued)";
  
  # Days of the week ELF: Added to include them in normal noun (NN) count rather than NNP (currently not in use)
  #$days = "(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon\.+|Tue\.+|Wed\.+|Thu\.+|Fri\.+|Sat\.+|Sun\.+)";
  
  # Months ELF: Added to include them in normal noun (NN) count rather than NNP (currently not in use)
  #$months = "(January|Jan|February|Feb|March|Mar|April|Apr|May|May|June|Jun|July|Jul|August|Aug|September|Sep|October|Oct|November|Nov|December|Dec)";
  
  # Stative verbs  
  # ELF: This is a new list which was added on DS's suggestion to count JPRED adjectives more accurately. Predicative adjectives are now identified by exclusion (= adjectives not identified as attributive adjectives) but this dictionary remains useful to disambiguate between PASS and PEAS when the auxiliary is "'s".
  $v_stative = "(appear|appears|appeared|feel|feels|feeling|felt|look|looks|looking|looked|become|becomes|became|becoming|get|gets|getting|got|go|goes|going|gone|went|grow|grows|growing|grown|prove|proves|proven|remain|remains|remaining|remained|seem|seems|seemed|shine|shines|shined|shone|smell|smells|smelt|smelled|sound|sounds|sounded|sounding|stay|staying|stayed|stays|taste|tastes|tasted|turn|turns|turning|turned)";
  
  # Function words
  # EFL: Added in order to calculate a content to function word ratio to capture lexical density
  $function_words = "(a|about|above|after|again|ago|ai|all|almost|along|already|also|although|always|am|among|an|and|another|any|anybody|anything|anywhere|are|are|around|as|at|back|be|been|before|being|below|beneath|beside|between|beyond|billion|billionth|both|but|by|can|can|could|cos|cuz|did|do|does|doing|done|down|during|each|eight|eighteen|eighteenth|eighth|eightieth|eighty|either|eleven|eleventh|else|enough|even|ever|every|everybody|everyone|everything|everywhere|except|far|few|fewer|fifteen|fifteenth|fifth|fiftieth|fifty|first|five|for|fortieth|forty|four|fourteen|fourteenth|fourth|from|get|gets|getting|got|had|has|have|having|he|hence|her|here|hers|herself|him|himself|his|hither|how|however|hundred|hundredth|i|if|in|into|is|it|its|itself|just|last|less|many|may|me|might|million|millionth|mine|more|most|much|must|my|myself|near|near|nearby|nearly|neither|never|next|nine|nineteen|nineteenth|ninetieth|ninety|ninth|no|nobody|none|noone|nor|not|nothing|now|nowhere|of|off|often|on|once|one|only|or|other|others|ought|our|ours|ourselves|out|over|quite|rather|round|second|seven|seventeen|seventeenth|seventh|seventieth|seventy|shall|sha|she|should|since|six|sixteen|sixteenth|sixth|sixtieth|sixty|so|some|somebody|someone|something|sometimes|somewhere|soon|still|such|ten|tenth|than|that|that|the|their|theirs|them|themselves|then|thence|there|therefore|these|they|third|thirteen|thirteenth|thirtieth|thirty|this|thither|those|though|thousand|thousandth|three|thrice|through|thus|till|to|today|tomorrow|too|towards|twelfth|twelve|twentieth|twenty|twice|two|under|underneath|unless|until|up|us|very|was|we|were|what|when|whence|where|whereas|which|while|whither|who|whom|whose|why|will|with|within|without|wo|would|yes|yesterday|yet|you|your|yours|yourself|yourselves|'re|'ve|n't|'ll|'twas|'em|y'|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|1|2|3|4|5|6|7|8|9|0)";
  
  #Shakir: noun, adj, adv semantic categories from Biber 2006
  $nn_human = "(family|families|guy|guys|individual|individuals|kid|kids|man|men|manager|managers|member|members|parent|parents|teacher|teachers|child|children|people|peoples|person|people|student|students|woman|women|animal|animals|applicant|applicants|author|authors|baby|babies|boy|boys|client|clients|consumer|consumers|critic|critics|customer|customers|doctor|doctors|employee|employees|employer|employers|father|fathers|female|females|friend|friends|girl|girls|god|gods|historian|historians|husband|husbands|American|Americans|Indian|Indians|instructor|instructors|king|kings|leader|leaders|male|males|mother|mothers|owner|owners|president|presidents|professor|professors|researcher|researchers|scholar|scholars|speaker|speakers|species|species|supplier|suppliers|undergraduate|undergraduates|user|users|wife|wives|worker|workers|writer|writers|accountant|accountants|adult|adults|adviser|advisers|agent|agents|aide|aides|ancestor|ancestors|anthropologist|anthropologists|archaeologist|archaeologists|artist|artists|artiste|artistes|assistant|assistants|associate|associates|attorney|attorneys|audience|audiences|auditor|auditors|bachelor|bachelors|bird|birds|boss|bosses|brother|brothers|buddha|buddhas|buyer|buyers|candidate|candidates|cat|cats|citizen|citizens|colleague|colleagues|collector|collectors|competitor|competitors|counselor|counselors|daughter|daughters|deer|deer|defendant|defendants|designer|designers|developer|developers|director|directors|driver|drivers|economist|economists|engineer|engineers|executive|executives|expert|experts|farmer|farmers|feminist|feminists|freshman|freshmen|eologist|eologists|hero|heroes|host|hosts|hunter|hunters|immigrant|immigrants|infant|infants|investor|investors|jew|jews|judge|judges|lady|ladies|lawyer|lawyers|learner|learners|listener|listeners|maker|makers|manufacturer|manufacturers|miller|millers|minister|ministers|mom|moms|monitor|monitors|monkey|monkeys|neighbor|neighbors|observer|observers|officer|officers|official|officials|participant|participants|partner|partners|patient|patients|personnel|personnels|peer|peers|physician|physicians|plaintiff|plaintiffs|player|players|poet|poets|police|polices|processor|processors|professional|professionals|provider|providers|psychologist|psychologists|resident|residents|respondent|respondents|schizophrenic|schizophrenics|scientist|scientists|secretary|secretaries|server|servers|shareholder|shareholders|sikh|sikhs|sister|sisters|slave|slaves|son|sons|spouse|spouses|supervisor|supervisors|theorist|theorists|tourist|tourists|victim|victims|faculty|faculties|dean|deans|engineer|engineers|reader|readers|couple|couples|graduate|graduates|Pakistanis?|Bangladeshis?|Srilanakns?)";
  $nn_cog = "(analysis|analyses|decision|decisions|experience|experiences|assessment|assessments|calculation|calculations|conclusion|conclusions|consequence|consequences|consideration|considerations|evaluation|evaluations|examination|examinations|expectation|expectations|observation|observations|recognition|recognitions|relation|relations|understanding|understandings|hypothesis|hypotheses|ability|abilities|assumption|assumptions|attention|attentions|attitude|attitudes|belief|beliefs|concentration|concentrations|concern|concerns|consciousness|consciousnesses|concept|concepts|fact|facts|idea|ideas|knowledge|knowledges|look|looks|need|needs|reason|reasons|sense|senses|view|views|theory|theories|desire|desires|emotion|emotions|feeling|feelings|judgement|judgements|memory|memories|notion|notions|opinion|opinions|perception|perceptions|perspective|perspectives|possibility|possibilities|probability|probabilities|responsibility|responsibilities|thought|thoughts)";
  $nn_concrete = "(tank|tanks|stick|sticks|target|targets|strata|stratas|telephone|telephones|string|strings|telescope|telescopes|sugar|sugars|ticket|tickets|syllabus|syllabuses|tip|tips|salt|salts|tissue|tissues|screen|screens|tooth|teeth|sculpture|sculptures|sphere|spheres|seawater|seawaters|spot|spots|ship|ships|steam|steams|silica|silicas|steel|steels|slide|slides|stem|stems|snow|snows|sodium|mud|muds|solid|solids|mushroom|mushrooms|gift|gifts|muscle|muscles|glacier|glaciers|tube|tubes|gun|guns|nail|nails|handbook|handbooks|newspaper|newspapers|handout|handouts|node|nodes|instrument|instruments|notice|notices|knot|knots|novel|novels|lava|lavas|page|pages|food|foods|transcript|transcripts|leg|legs|eye|eyes|lemon|lemons|brain|brains|magazine|magazines|device|devices|magnet|magnets|oak|oaks|manual|manuals|package|packages|marker|markers|peak|peaks|match|matches|pen|pens|metal|metals|pencil|pencils|block|blocks|pie|pies|board|boards|pipe|pipes|heart|hearts|load|loads|paper|papers|transistor|transistors|modem|modems|book|books|mole|moles|case|cases|motor|motors|computer|computers|mound|mounds|dollar|dollars|mouth|mouths|hand|hands|movie|movies|flower|flowers|object|objects|foot|feet|table|tables|frame|frames|water|waters|vessel|vessels|arm|arms|visa|visas|bar|bars|grain|grains|bed|beds|hair|hairs|body|bodies|head|heads|box|boxes|ice|ices|car|cars|item|items|card|cards|journal|journals|chain|chains|key|keys|chair|chairs|window|windows|vehicle|vehicles|leaf|leaves|copy|copies|machine|machines|document|documents|mail|mails|door|doors|map|maps|dot|dots|phone|phones|drug|drugs|picture|pictures|truck|trucks|piece|pieces|tape|tapes|note|notes|liquid|liquids|wire|wires|equipment|equipments|wood|woods|fiber|fibers|plant|plants|fig|figs|resistor|resistors|film|films|sand|sands|file|files|score|scores|seat|seats|belt|belts|sediment|sediments|boat|boats|seed|seeds|bone|bones|soil|soils|bubble|bubbles|bud|buds|water|waters|bulb|bulbs|portrait|portraits|bulletin|bulletins|step|steps|shell|shells|stone|stones|cake|cakes|tree|trees|camera|cameras|video|videos|face|faces|wall|walls|acid|acids|alcohol|alcohols|cap|caps|aluminium|aluminiums|clay|clays|artifact|artifacts|clock|clocks|rain|rains|clothing|clothings|asteroid|asteroids|club|clubs|automobile|automobiles|comet|comets|award|awards|sheet|sheets|bag|bags|branch|branches|ball|balls|copper|coppers|banana|bananas|counter|counters|band|bands|cover|covers|wheel|wheels|crop|crops|drop|drops|crystal|crystals|basin|basins|cylinder|cylinders|bell|bells|desk|desks|dinner|dinners|pole|poles|button|buttons|pot|pots|disk|disks|pottery|potteries|drain|drains|radio|radios|drink|drinks|reactor|reactors|drawing|drawings|retina|retinas|dust|dusts|ridge|ridges|edge|edges|ring|rings|engine|engines|ripple|ripples|plate|plates|game|games|cent|cents|post|posts|envelope|envelopes|rock|rocks|filter|filters|root|roots|finger|fingers|slope|slopes|fish|fish|space|spaces|fruit|fruits|statue|statues|furniture|furnitures|textbook|textbooks|gap|gaps|tool|tools|gate|gates|train|trains|gel|gels|deposit|deposits|chart|charts|mixture|mixtures)";
  $nn_technical = "(cell|cells|unit|units|gene|genes|wave|waves|ion|ions|bacteria|bacterias|electron|electrons|chromosome|chromosomes|element|elements|cloud|clouds|sample|samples|isotope|isotopes|schedule|schedules|neuron|neurons|software|softwares|nuclei|nucleus|solution|solutions|nucleus|nuclei|atom|atoms|ray|rays|margin|margins|virus|viruses|mark|marks|hydrogen|hydrogens|mineral|minerals|internet|internets|molecule|molecules|mineral|minerals|organism|organisms|message|messages|oxygen|oxygens|paragraph|paragraphs|particle|particles|sentence|sentences|play|plays|star|stars|poem|poems|thesis|theses|proton|protons|unit|units|web|webs|layer|layers|center|centers|matter|matters|chapter|chapters|square|squares|data|circle|circles|equation|equations|compound|compounds|exam|exams|letter|letters|bill|bills|page|pages|component|components|statement|statements|diagram|diagrams|word|words|dna|angle|angles|fire|fires|carbon|carbons|formula|formulas|graph|graphs|iron|irons|lead|leads|jury|juries|light|lights|list|lists)";
  $nn_place = "(apartment|apartments|interior|interiors|bathroom|bathrooms|moon|moons|bay|bays|museum|museums|bench|benches|neighborhood|neighborhoods|bookstore|bookstores|opposite|opposites|border|borders|orbit|orbits|cave|caves|orbital|orbitals|continent|continents|outside|outsides|delta|deltas|parallel|parallels|desert|deserts|passage|passages|estuary|estuaries|pool|pools|factory|factories|prison|prisons|farm|farms|restaurant|restaurants|forest|forests|sector|sectors|habitat|habitats|shaft|shafts|hell|hells|shop|shops|hemisphere|hemispheres|southwest|hill|hills|station|stations|hole|holes|territory|territories|horizon|horizons|road|roads|bottom|bottoms|store|stores|boundary|boundaries|stream|streams|building|buildings|top|tops|campus|campuses|valley|valleys|canyon|canyons|village|villages|coast|coasts|city|cities|county|counties|country|countries|court|courts|earth|earths|front|fronts|environment|environments|district|districts|field|fields|floor|floors|market|markets|lake|lakes|office|offices|land|lands|organization|organizations|lecture|lectures|place|places|left|lefts|room|rooms|library|libraries|area|areas|location|locations|class|classes|middle|middles|classroom|classrooms|mountain|mountains|ground|grounds|north|norths|hall|halls|ocean|oceans|park|parks|planet|planets|property|properties|region|regions|residence|residences|river|rivers)";
  $nn_quant = "(cycle|cycles|rate|rates|date|dates|second|seconds|frequency|frequencies|section|sections|future|futures|semester|semesters|half|halves|temperature|temperatures|height|heights|today|todays|number|numbers|amount|amounts|week|weeks|age|ages|day|days|century|centuries|part|parts|energy|energies|lot|lots|heat|heats|term|terms|hour|hours|time|times|month|months|mile|miles|period|periods|moment|moments|morning|mornings|volume|volumes|per|weekend|weekends|percentage|percentages|weight|weights|portion|portions|minute|minutes|quantity|quantities|percent|percents|quarter|quarters|length|lengths|ratio|ratios|measure|measures|summer|summers|meter|meters|volt|volts|voltage|voltages)";
  $nn_group = "(airline|airlines|institute|institutes|colony|colonies|bank|banks|flight|flights|church|churches|hotel|hotels|firm|firms|hospital|hospitals|household|households|college|colleges|institution|institutions|house|houses|lab|labs|laboratory|laboratories|community|communities|company|companies|government|governments|university|universities|school|schools|home|homes|congress|congresses|committee|committees)";
  $nn_abstract_process = "(action|actions|activity|activities|application|applications|argument|arguments|development|developments|education|educations|effect|effects|function|functions|method|methods|research|researches|result|results|process|processes|accounting|accountings|achievement|achievements|addition|additions|administration|administrations|approach|approaches|arrangement|arrangements|assignment|assignments|competition|competitions|construction|constructions|consumption|consumptions|contribution|contributions|counseling|counselings|criticism|criticisms|definition|definitions|discrimination|discriminations|description|descriptions|discussion|discussions|distribution|distributions|division|divisions|eruption|eruptions|evolution|evolutions|exchange|exchanges|exercise|exercises|experiment|experiments|explanation|explanations|expression|expressions|formation|formations|generation|generations|graduation|graduations|management|managements|marketing|marketings|marriage|marriages|mechanism|mechanisms|meeting|meetings|operation|operations|orientation|orientations|performance|performances|practice|practices|presentation|presentations|procedure|procedures|production|productions|progress|progresses|reaction|reactions|registration|registrations|regulation|regulations|revolution|revolutions|selection|selections|session|sessions|strategy|strategies|teaching|teachings|technique|techniques|tradition|traditions|training|trainings|transition|transitions|treatment|treatments|trial|trials|act|acts|agreement|agreements|attempt|attempts|attendance|attendances|birth|births|break|breaks|claim|claims|comment|comments|comparison|comparisons|conflict|conflicts|deal|deals|death|deaths|debate|debates|demand|demands|answer|answers|control|controls|flow|flows|service|services|work|works|test|tests|use|uses|war|wars|change|changes|question|questions|study|studies|talk|talks|task|tasks|trade|trades|transfer|transfers|admission|admissions|design|designs|detail|details|dimension|dimensions|direction|directions|disorder|disorders|diversity|diversities|economy|economies|emergency|emergencies|emphasis|emphases|employment|employments|equilibrium|equilibriums|equity|equities|error|errors|expense|expenses|facility|facilities|failure|failures|fallacy|fallacies|feature|features|format|formats|freedom|freedoms|fun|funs|gender|genders|goal|goals|grammar|grammars|health|healths|heat|heats|help|helps|identity|identities|image|images|impact|impacts|importance|importances|influence|influences|input|inputs|labor|labors|leadership|leaderships|link|links|manner|manners|math|maths|matrix|matrices|meaning|meanings|music|musics|network|networks|objective|objectives|opportunity|opportunities|option|options|origin|origins|output|outputs|past|pasts|pattern|patterns|phase|phases|philosophy|philosophies|plan|plans|potential|potentials|prerequisite|prerequisites|presence|presences|principle|principles|success|successes|profile|profiles|profit|profits|proposal|proposals|psychology|psychologies|quality|qualities|quiz|quizzes|race|races|reality|realities|religion|religions|resource|resources|respect|respects|rest|rests|return|returns|risk|risks|substance|substances|scene|scenes|security|securities|series|series|set|sets|setting|settings|sex|sexes|shape|shapes|share|shares|show|shows|sign|signs|signal|signals|sort|sorts|sound|sounds|spring|springs|stage|stages|standard|standards|start|starts|stimulus|stimuli|strength|strengths|stress|stresses|style|styles|support|supports|survey|surveys|symbol|symbols|topic|topics|track|tracks|trait|traits|trouble|troubles|truth|truths|variation|variations|variety|varieties|velocity|velocities|version|versions|whole|wholes|action|actions|account|accounts|condition|conditions|culture|cultures|end|ends|factor|factors|grade|grades|interest|interests|issue|issues|job|jobs|kind|kinds|language|languages|law|laws|level|levels|life|lives|model|models|name|names|nature|natures|order|orders|policy|policies|position|positions|power|powers|pressure|pressures|relationship|relationships|requirement|requirements|role|roles|rule|rules|science|sciences|side|sides|situation|situations|skill|skills|source|sources|structure|structures|subject|subjects|type|types|information|informations|right|rights|state|states|system|systems|value|values|way|ways|address|addresses|absence|absences|advantage|advantages|aid|aids|alternative|alternatives|aspect|aspects|authority|authorities|axis|axes|background|backgrounds|balance|balances|base|bases|beginning|beginnings|benefit|benefits|bias|biases|bond|bonds|capital|capitals|care|cares|career|careers|cause|causes|characteristic|characteristics|charge|charges|check|checks|choice|choices|circuit|circuits|circumstance|circumstances|climate|climates|code|codes|color|colors|column|columns|combination|combinations|complex|complexes|connection|connections|constant|constants|constraint|constraints|contact|contacts|content|contents|contract|contracts|context|contexts|contrast|contrasts|crime|crimes|criteria|criterias|cross|crosses|current|currents|curriculum|curriculums|curve|curves|debt|debts|density|densities)";
  $advl_nonfact = "(confidentially|frankly|generally|honestly|mainly|technically|truthfully|typically|reportedly|primarily|usually)";
  $advl_att = "(amazingly|astonishingly|conveniently|curiously|hopefully|fortunately|importantly|ironically|rightly|sadly|surprisingly|unfortunately)";
  $advl_fact = "(actually|always|certainly|definitely|indeed|inevitably|never|obviously|really|undoubtedly|nodoubt|ofcourse|infact)";
  $advl_likely = "(apparently|evidently|perhaps|possibly|predictably|probably|roughly|maybe)";
  $jj_size = "(big|deep|heavy|huge|long|large|little|short|small|thin|wide|narrow)";
  $jj_time = "(annual|daily|early|late|new|old|recent|young|weekly|monthly)";
  $jj_color = "(black|white|dark|bright|blue|browm|green|gr[ae]y|red)";
  $jj_eval = "(bad|beautiful|best|fine|good|great|lovely|nice|poor)";
  $jj_relation = "(additional|average|chief|complete|different|direct|entire|external|final|following|general|initial|internal|left|main|maximum|necessary|original|particular|previous|primary|public|similar|single|standard|top|various|same)";
  $jj_topic = "(chemical|commercial|environmental|human|industrial|legal|medical|mental|official|oral|phonetic|political|sexual|social|ventral|visual)";
  $jj_att_other = "(afraid|amazed|(un)?aware|concerned|disappointed|encouraged|glad|happy|hopeful|pleased|shocked|surprised|worried)";
  $jj_epist_other = "(apparent|certain|clear|confident|convinced|correct|evident|false|impossible|inevitable|obvious|positive|right|sure|true|well-known|doubtful|likely|possible|probable|unlikely)";
  $comm_vb_other = "(say|says|saying|said|tell|tells|telling|told|call|calls|calling|called|ask|asks|asking|asked|write|writes|writing|wrote|written|talk|talks|talking|talked|speak|speaks|spoke|spoken|speaking|thank|thanks|thanking|thanked|describe|describing|describes|described|claim|claims|claiming|claimed|offer|offers|offering|offered|admit|admits|admitting|admitted|announce|announces|announcing|announced|answer|answers|answering|answered|argue|argues|arguing|argued|deny|denies|denying|denied|discuss|discusses|discussing|discussed|encourage|encourages|encouraging|encouraged|explain|explains|explaining|explained|express|expresses|expressing|expressed|insist|insists|insisting|insisted|mention|mentions|mentioning|mentioned|offer|offers|offering|offered|propose|proposes|proposing|proposed|quote|quotes|quoting|quoted|reply|replies|replying|replied|shout|shouts|shouting|shouted|sign|signs|signing|signed|sing|sings|singing|sang|sung|state|states|stating|stated|teach|teaches|teaching|taught|warn|warns|warning|warned|accuse|accuses|accusing|accused|acknowledge|acknowledges|acknowledging|acknowledged|address|addresses|addressing|addressed|advise|advises|advising|advised|appeal|appeals|appealing|appealed|assure|assures|assuring|assured|challenge|challenges|challenging|challenged|complain|complains|complaining|complained|consult|consults|consulting|consulted|convince|convinces|convincing|convinced|declare|declares|declaring|declared|demand|demands|demanding|demanded|emphasize|emphasizes|emphasizing|emphasized|emphasise|emphasises|emphasising|emphasised|excuse|excuses|excusing|excused|inform|informs|informing|informed|invite|invites|inviting|invited|persuade|persuades|persuading|persuaded|phone|phones|phoning|phoned|pray|prays|praying|prayed|promise|promises|promising|promised|question|questions|questioning|questioned|recommend|recommends|recommending|recommended|remark|remarks|remarking|remarked|respond|responds|responding|responded|specify|specifies|specifying|specified|swear|swears|swearing|swore|sworn|threaten|threatens|threatening|threatened|urge|urges|urging|urged|welcome|welcomes|welcoming|welcomed|whisper|whispers|whispering|whispered|suggest|suggests|suggesting|suggested|plead|pleads|pleaded|pleading|agree|agrees|agreed|agreeing|assert|asserts|asserting|asserted|beg|begs|begging|begged|confide|confides|confiding|confided|command|commands|commanding|commanded|disagree|disagreeing|disagrees|disagreed|object|objects|objected|objects|pledge|pledges|pledging|pledged|report|reports|reported|reporting|testify|testifies|testified|testifying|vow|vows|vowing|vowed|mean|means|meaning|meant)";
  $att_vb_other = "(agreeing|agreed|agree|agrees|anticipates|anticipated|anticipate|anticipating|complain|complained|complaining|complains|conceded|concede|concedes|conceding|ensure|expecting|expect|expects|expected|fears|feared|fear|fearing|feel|feels|feeling|felt|forgetting|forgets|forgotten|forgot|forget|hoped|hope|hopes|hoping|minding|minded|minds|mind|preferred|prefer|preferring|prefers|pretending|pretend|pretended|pretends|requiring|required|requires|require|wishes|wished|wish|wishing|worry|worrying|worries|worried)";
  $fact_vb_other = "(concluding|conclude|concluded|concludes|demonstrates|demonstrating|demonstrated|demonstrate|determining|determines|determine|determined|discovered|discovers|discover|discovering|finds|finding|found|find|knows|known|knowing|know|knew|learn|learns|learning|learnt|means|meaning|meant|mean|notifies|notices|notice|noticed|notify|notifying|noticing|notified|observed|observes|observing|observe|proven|prove|proving|proved|proves|reali(z|s)ed|reali(z|s)es|reali(z|s)e|reali(z|s)ing|recogni(z|s)es|recogni(z|s)e|recogni(z|s)ed|recogni(z|s)ing|remembered|remember|remembers|remembering|sees|seen|saw|seeing|see|showing|shows|shown|showed|show|understand|understands|understanding|understood)";
  $likely_vb_other = "(assumes|assumed|assuming|assume|believe|believing|believes|believed|doubting|doubted|doubts|doubt|gathers|gathering|gathered|gather|guessed|guess|guessing|guesses|hypothesi(z|s)ing|hypothesi(z|s)ed|hypothesi(z|s)e|hypothesi(z|s)es|imagine|imagining|imagines|imagined|predict|predicted|predicting|predicts|presupposing|presupposes|presuppose|presupposed|presumes|presuming|presumed|presume|reckon|reckoning|reckoned|reckons|seemed|seems|seem|seeming|speculated|speculate|speculating|speculates|suppose|supposes|supposing|supposed|suspected|suspect|suspects|suspecting|think|thinks|thinking|thought)";
  
  #Shakir: vocabulary lists for that, wh and to clauses governed by semantic classes of verbs, nouns, adjectives
  $th_vb_comm = "(say|says|saying|said|tell|tells|telling|told|call|calls|calling|called|ask|asks|asking|asked|write|writes|writing|wrote|written|talk|talks|talking|talked|speak|speaks|spoke|spoken|speaking|thank|thanks|thanking|thanked|describe|describing|describes|described|claim|claims|claiming|claimed|offer|offers|offering|offered|admit|admits|admitting|admitted|announce|announces|announcing|announced|answer|answers|answering|answered|argue|argues|arguing|argued|deny|denies|denying|denied|discuss|discusses|discussing|discussed|encourage|encourages|encouraging|encouraged|explain|explains|explaining|explained|express|expresses|expressing|expressed|insist|insists|insisting|insisted|mention|mentions|mentioning|mentioned|offer|offers|offering|offered|propose|proposes|proposing|proposed|quote|quotes|quoting|quoted|reply|replies|replying|replied|shout|shouts|shouting|shouted|sign|signs|signing|signed|sing|sings|singing|sang|sung|state|states|stating|stated|teach|teaches|teaching|taught|warn|warns|warning|warned|accuse|accuses|accusing|accused|acknowledge|acknowledges|acknowledging|acknowledged|address|addresses|addressing|addressed|advise|advises|advising|advised|appeal|appeals|appealing|appealed|assure|assures|assuring|assured|challenge|challenges|challenging|challenged|complain|complains|complaining|complained|consult|consults|consulting|consulted|convince|convinces|convincing|convinced|declare|declares|declaring|declared|demand|demands|demanding|demanded|emphasize|emphasizes|emphasizing|emphasized|emphasise|emphasises|emphasising|emphasised|excuse|excuses|excusing|excused|inform|informs|informing|informed|invite|invites|inviting|invited|persuade|persuades|persuading|persuaded|phone|phones|phoning|phoned|pray|prays|praying|prayed|promise|promises|promising|promised|question|questions|questioning|questioned|recommend|recommends|recommending|recommended|remark|remarks|remarking|remarked|respond|responds|responding|responded|specify|specifies|specifying|specified|swear|swears|swearing|swore|sworn|threaten|threatens|threatening|threatened|urge|urges|urging|urged|welcome|welcomes|welcoming|welcomed|whisper|whispers|whispering|whispered|suggest|suggests|suggesting|suggested|plead|pleads|pleaded|pleading|agree|agrees|agreed|agreeing|assert|asserts|asserting|asserted|beg|begs|begging|begged|confide|confides|confiding|confided|command|commands|commanding|commanded|disagree|disagreeing|disagrees|disagreed|object|objects|objected|objects|pledge|pledges|pledging|pledged|report|reports|reported|reporting|testify|testifies|testified|testifying|vow|vows|vowing|vowed|mean|means|meaning|meant)";
  $th_vb_att = "(agreeing|agreed|agree|agrees|anticipates|anticipated|anticipate|anticipating|complain|complained|complaining|complains|conceded|concede|concedes|conceding|ensure|expecting|expect|expects|expected|fears|feared|fear|fearing|feel|feels|feeling|felt|forgetting|forgets|forgotten|forgot|forget|hoped|hope|hopes|hoping|minding|minded|minds|mind|preferred|prefer|preferring|prefers|pretending|pretend|pretended|pretends|requiring|required|requires|require|wishes|wished|wish|wishing|worry|worrying|worries|worried)";
  $th_vb_fact = "(concluding|conclude|concluded|concludes|demonstrates|demonstrating|demonstrated|demonstrate|determining|determines|determine|determined|discovered|discovers|discover|discovering|finds|finding|found|find|knows|known|knowing|know|knew|learn|learns|learning|learnt|means|meaning|meant|mean|notifies|notices|notice|noticed|notify|notifying|noticing|notified|observed|observes|observing|observe|proven|prove|proving|proved|proves|reali(z|s)ed|reali(z|s)es|reali(z|s)e|reali(z|s)ing|recogni(z|s)es|recogni(z|s)e|recogni(z|s)ed|recogni(z|s)ing|remembered|remember|remembers|remembering|sees|seen|saw|seeing|see|showing|shows|shown|showed|show|understand|understands|understanding|understood)";
  $th_vb_likely = "(assumes|assumed|assuming|assume|believe|believing|believes|believed|doubting|doubted|doubts|doubt|gathers|gathering|gathered|gather|guessed|guess|guessing|guesses|hypothesi(z|s)ing|hypothesi(z|s)ed|hypothesi(z|s)e|hypothesi(z|s)es|imagine|imagining|imagines|imagined|predict|predicted|predicting|predicts|presupposing|presupposes|presuppose|presupposed|presumes|presuming|presumed|presume|reckon|reckoning|reckoned|reckons|seemed|seems|seem|seeming|speculated|speculate|speculating|speculates|suppose|supposes|supposing|supposed|suspected|suspect|suspects|suspecting|think|thinks|thinking|thought)";
  $to_vb_desire = "(agreeing|agreed|agree|agrees|chooses|chosen|choose|choosing|chose|decide|deciding|decided|decides|hate|hates|hating|hated|hesitated|hesitates|hesitate|hesitating|hoped|hope|hopes|hoping|intended|intend|intending|intends|likes|liked|like|liking|loving|loves|love|loved|means|meaning|meant|mean|needs|need|needing|needed|planning|plan|planned|plans|preferred|prefer|preferring|prefers|prepares|prepare|preparing|prepared|refuses|refusing|refuse|refused|wanting|want|wants|wanted|wishes|wished|wish|wishing)";
  $to_vb_effort = "(allowance|allowing|allowed|allowancing|allow|allowances|allows|allowanced|attempting|attempted|attempts|attempt|enables|enabled|enabling|enable|encourages|encouraging|encouraged|encourage|fails|fail|failing|failed|help|helping|helps|helped|instructs|instructed|instruct|instructing|managing|managed|manage|manages|oblige|obligate|obliged|obligates|obliging|obligating|obliges|obligated|order|ordering|orders|ordered|permitted|permits|permit|permitting|persuaded|persuades|persuade|persuading|prompts|prompting|prompted|prompt|requiring|requisitions|requisitioning|required|requires|requisition|requisitioned|require|sought|seeking|seeks|seek|try|trying|tries|tried)";
  $to_vb_prob = "(appear|appeared|appears|appearing|happens|happened|happen|happening|seemed|seems|seem|seeming|tending|tends|tended|tend)";
  $to_vb_speech = "(asks|ask|asking|asked|claiming|claims|claim|claimed|invite|inviting|invited|invites|promising|promised|promise|promises|reminding|remind|reminded|reminds|requesting|request|requests|requested|saying|say|said|says|teaches|teaching|taught|teach|tell|tells|telling|told|urging|urges|urged|urge|warning|warn|warned|warns)";
  $to_vb_mental = "(assumed|assumes|assume|assuming|believing|believes|believe|believed|considered|considers|consider|considering|expecting|expects|expected|expect|find|found|finding|finds|forgetting|forget|forgets|forgot|forgotten|imagine|imagined|imagining|imagines|judge|adjudicates|adjudicate|judges|judged|knowing|knows|known|know|knew|learnt|learning|learns|learn|presumes|presuming|presumed|presume|pretend|pretends|pretended|pretending|remembered|remember|remembers|remembering|supposing|suppose|supposes|supposed)";
  $wh_vb_att = "(agreeing|agreed|agree|agrees|anticipates|anticipated|anticipate|anticipating|complain|complained|complaining|complains|conceded|concede|concedes|conceding|ensure|expecting|expect|expects|expected|fears|feared|fear|fearing|feel|feels|feeling|felt|forgetting|forgets|forgotten|forgot|forget|hoped|hope|hopes|hoping|minding|minded|minds|mind|preferred|prefer|preferring|prefers|pretending|pretend|pretended|pretends|requiring|required|requires|require|wishes|wished|wish|wishing|worry|worrying|worries|worried)";
  $wh_vb_fact = "(concluding|conclude|concluded|concludes|demonstrates|demonstrating|demonstrated|demonstrate|determining|determines|determine|determined|discovered|discovers|discover|discovering|finds|finding|found|find|knows|known|knowing|know|knew|learn|learns|learning|learnt|means|meaning|meant|mean|notifies|notices|notice|noticed|notify|notifying|noticing|notified|observed|observes|observing|observe|proven|prove|proving|proved|proves|reali(z|s)ed|reali(z|s)es|reali(z|s)e|reali(z|s)ing|recogni(z|s)es|recogni(z|s)e|recogni(z|s)ed|recogni(z|s)ing|remembered|remember|remembers|remembering|sees|seen|saw|seeing|see|showing|shows|shown|showed|show|understand|understands|understanding|understood)";
  $wh_vb_likely = "(assumes|assumed|assuming|assume|believe|believing|believes|believed|doubting|doubted|doubts|doubt|gathers|gathering|gathered|gather|guessed|guess|guessing|guesses|hypothesi(z|s)ing|hypothesi(z|s)ed|hypothesi(z|s)e|hypothesi(z|s)es|imagine|imagining|imagines|imagined|predict|predicted|predicting|predicts|presupposing|presupposes|presuppose|presupposed|presumes|presuming|presumed|presume|reckon|reckoning|reckoned|reckons|seemed|seems|seem|seeming|speculated|speculate|speculating|speculates|suppose|supposes|supposing|supposed|suspected|suspect|suspects|suspecting|think|thinks|thinking|thought)";
  $wh_vb_comm = "(say|says|saying|said|tell|tells|telling|told|call|calls|calling|called|ask|asks|asking|asked|write|writes|writing|wrote|written|talk|talks|talking|talked|speak|speaks|spoke|spoken|speaking|thank|thanks|thanking|thanked|describe|describing|describes|described|claim|claims|claiming|claimed|offer|offers|offering|offered|admit|admits|admitting|admitted|announce|announces|announcing|announced|answer|answers|answering|answered|argue|argues|arguing|argued|deny|denies|denying|denied|discuss|discusses|discussing|discussed|encourage|encourages|encouraging|encouraged|explain|explains|explaining|explained|express|expresses|expressing|expressed|insist|insists|insisting|insisted|mention|mentions|mentioning|mentioned|offer|offers|offering|offered|propose|proposes|proposing|proposed|quote|quotes|quoting|quoted|reply|replies|replying|replied|shout|shouts|shouting|shouted|sign|signs|signing|signed|sing|sings|singing|sang|sung|state|states|stating|stated|teach|teaches|teaching|taught|warn|warns|warning|warned|accuse|accuses|accusing|accused|acknowledge|acknowledges|acknowledging|acknowledged|address|addresses|addressing|addressed|advise|advises|advising|advised|appeal|appeals|appealing|appealed|assure|assures|assuring|assured|challenge|challenges|challenging|challenged|complain|complains|complaining|complained|consult|consults|consulting|consulted|convince|convinces|convincing|convinced|declare|declares|declaring|declared|demand|demands|demanding|demanded|emphasize|emphasizes|emphasizing|emphasized|emphasise|emphasises|emphasising|emphasised|excuse|excuses|excusing|excused|inform|informs|informing|informed|invite|invites|inviting|invited|persuade|persuades|persuading|persuaded|phone|phones|phoning|phoned|pray|prays|praying|prayed|promise|promises|promising|promised|question|questions|questioning|questioned|recommend|recommends|recommending|recommended|remark|remarks|remarking|remarked|respond|responds|responding|responded|specify|specifies|specifying|specified|swear|swears|swearing|swore|sworn|threaten|threatens|threatening|threatened|urge|urges|urging|urged|welcome|welcomes|welcoming|welcomed|whisper|whispers|whispering|whispered|suggest|suggests|suggesting|suggested|plead|pleads|pleaded|pleading|agree|agrees|agreed|agreeing|assert|asserts|asserting|asserted|beg|begs|begging|begged|confide|confides|confiding|confided|command|commands|commanding|commanded|disagree|disagreeing|disagrees|disagreed|object|objects|objected|objects|pledge|pledges|pledging|pledged|report|reports|reported|reporting|testify|testifies|testified|testifying|vow|vows|vowing|vowed|mean|means|meaning|meant)";
  $th_jj_att = "(afraid|amazed|(un)?aware|concerned|disappointed|encouraged|glad|happy|hopeful|pleased|shocked|surprised|worried)";
  $th_jj_fact = "(apparent|certain|clear|confident|convinced|correct|evident|false|impossible|inevitable|obvious|positive|right|sure|true|well-known)";
  $th_jj_likely = "(doubtful|likely|possible|probable|unlikely)";
  $th_jj_eval = "(amazing|appropriate|conceivable|crucial|essential|fortunate|imperative|inconceivable|incredible|interesting|lucky|necessary|nice|noteworthy|odd|ridiculous|strange|surprising|unacceptable|unfortunate)";
  $th_nn_nonfact = "(comment|comments|news|news|proposal|proposals|proposition|propositions|remark|remarks|report|reports|requirement|requirements)";
  $th_nn_att = "(grounds|ground|hope|hopes|reason|reasons|view|views|thought|thoughts)";
  $th_nn_fact = "(assertion|assertions|conclusion|conclusions|conviction|convictions|discovery|discoveries|doubt|doubts|fact|facts|knowledge|knowledges|observation|observations|principle|principles|realization|realizations|result|results|statement|statements)";
  $th_nn_likely = "(assumption|assumptions|belief|beliefs|claim|claims|contention|contentions|feeling|feelings|hypothesis|hypotheses|idea|ideas|implication|implications|impression|impressions|notion|notions|opinion|opinions|possibility|possibilities|presumption|presumptions|suggestion|suggestions)";
  $to_jj_certain = "(apt|certain|due|guaranteed|liable|likely|prone|unlikely|sure)";
  $to_jj_able = "(anxious|(un)?able|careful|determined|eager|eligible|hesitant|inclined|obliged|prepared|ready|reluctant|(un)?willing)";
  $to_jj_affect = "(afraid|ashamed|disappointed|embarrassed|glad|happy|pleased|proud|puzzled|relieved|sorry|surprised|worried)";
  $to_jj_ease = "(difficult|easier|easy|hard|(im)?possible|tough)";
  $to_jj_eval = "(bad|worse|(in)?appropriate|good|better|best|convenient|essential|important|interesting|necessary|nice|reasonable|silly|smart|stupid|surprising|useful|useless|unreasonable|wise|wrong)";
  $to_nn_stance_all = "(agreement|agreements|decision|decisions|desire|desires|failure|failures|inclination|inclinations|intention|intentions|obligation|obligations|opportunity|opportunities|plan|plans|promise|promises|proposal|proposals|reluctance|reluctances|responsibility|responsibilities|right|rights|tendency|tendencies|threat|threats|wish|wishes|willingness|willingnesses)";
  $nn_stance_pp = "(assertion|assertions|conclusion|conclusions|conviction|convictions|discovery|discoveries|doubt|doubts|fact|facts|knowledge|knowledges|observation|observations|principle|principles|realization|realizations|result|results|statement|statements|assumption|assumptions|belief|beliefs|claim|claims|contention|contentions|feeling|feelings|hypothesis|hypotheses|idea|ideas|implication|implications|impression|impressions|notion|notions|opinion|opinions|possibility|possibilities|presumption|presumptions|suggestion|suggestions|grounds|ground|hope|hopes|reason|reasons|view|views|thought|thoughts|comment|comments|news|news|proposal|proposals|proposition|propositions|remark|remarks|report|reports|requirement|requirements|agreement|agreements|decision|decisions|desire|desires|failure|failures|inclination|inclinations|intention|intentions|obligation|obligations|opportunity|opportunities|plan|plans|promise|promises|reluctance|reluctances|responsibility|responsibilities|right|rights|tendency|tendencies|threat|threats|wish|wishes|willingness|willingnesses)";

    # ELF added variable: Emojis :)
    # Should match all official emoji as of Dec 2018 :)
    # Cf. https://unicode.org/emoji/charts-11.0/full-emoji-list.html
    # Cf. https://www.mclean.net.nz/ucf/
    $emoji = "(😀|😁|😂|🤣|😃|😄|😅|😆|😉|😊|😋|😎|😍|😘|🥰|😗|😙|😚|☺|(\u263A)️|🙂|🤗|🤩|🤔|🤨|😐|😑|😶|🙄|😏|😣|😥|😮|🤐|😯|😪|😫|😴|😌|😛|😜|😝|🤤|😒|😓|😔|😕|🙃|🤑|😲|☹️|(\u2639)|🙁|😖|😞|😟|😤|😢|😭|😦|😧|😨|😩|🤯|😬|😰|😱|🥵|🥶|😳|🤪|😵|😡|😠|🤬|😷|🤒|🤕|🤢|🤮|🤧|😇|🤠|🤡|🥳|🥴|🥺|🤥|🤫|🤭|🧐|🤓|😈|👿|👹|👺|💀|👻|👽|🤖|💩|😺|😸|😹|😻|😼|😽|🙀|😿|😾|👶|👧|🧒|👦|👩|🧑|👨|👵|🧓|👴|👲|👳‍️|👳‍️|🧕|🧔|👱‍|👱‍️|👨‍|👩‍|🦸‍️|🦹‍️|👮‍️|👷‍️|💂‍️️|🕵️‍️|👩‍|👨‍|👰|🤵|👸|🤴|🤶|🎅|🧙‍️️|🧝‍️️|🧛‍️️|🧟‍️️|🧞‍️️|🧜‍️️|🧚‍️️|👼|🤰|🤱|🙇‍️️|💁‍️️|🙅‍️|🙆‍️|🙋‍️️|🤦‍️|🤷‍️|🙎‍️️|🙍‍️️|💇‍️️|💆‍️|🧖‍️️|💅|🤳|💃|🕺|👯‍️️|🕴|🚶‍️|🏃‍️|👫|👭|👬|💑|👩‍|👨‍|💏|👪|🤲|👐|🙌|👏|🤝|👍|👎|👊|✊|🤛|🤜|🤞|✌️|(\u270C)|🤟|🤘|👌|👈|👉|👆|👇|☝️|(\u261D)|✋|🤚|🖐|🖖|👋|🤙|💪|🦵|🦶|🖕|✍|(\u270D)|️🙏|💍|💄|💋|👄|👅|👂|👃|👣|👁|👀|🧠|🦴|🦷|🗣|👤|👥|🧥|👚|👕|👖|👔|👗|👙|👘|👠|👡|👢|👞|👟|🥾|🥿|🧦|🧤|🧣|🎩|🧢|👒|🎓|⛑|👑|👝|👛|👜|💼|🎒|👓|🕶|🥽|🥼|🌂|🧵|🧶|👶|👦|🐶|🐱|🐭|🐹|🐰|🦊|🦝|🐻|🐼|🦘|🦡|🐨|🐯|🦁|🐮|🐷|🐽|🐸|🐵|🙈|🙉|🙊|🐒|🐔|🐧|🐦|🐤|🐣|🐥|🦆|🦢|🦅|🦉|🦚|🦜|🦇|🐺|🐗|🐴|🦄|🐝|🐛|🦋|🐌|🐚|🐞|🐜|🦗|🕷|🕸|🦂|🦟|🦠|🐢|🐍|🦎|🦖|🦕|🐙|🦑|🦐|🦀|🐡|🐠|🐟|🐬|🐳|🐋|🦈|🐊|🐅|🐆|🦓|🦍|🐘|🦏|🦛|🐪|🐫|🦙|🦒|🐃|🐂|🐄|🐎|🐖|🐏|🐑|🐐|🦌|🐕|🐩|🐈|🐓|🦃|🕊|🐇|🐁|🐀|🐿|🦔|🐾|🐉|🐲|🌵|🎄|🌲|🌳|🌴|🌱|🌿|☘️|🍀|🎍|🎋|🍃|🍂|🍁|🍄|🌾|💐|🌷|🌹|🥀|🌺|🌸|🌼|🌻|🌞|🌝|🌛|🌜|🌚|🌕|🌖|🌗|🌘|🌑|🌒|🌓|🌔|🌙|🌎|🌍|🌏|💫|⭐|(\u2606)️️|🌟|✨|⚡️|☄️|(\u2604)|💥|🔥|🌪|🌈|☀️|(\u2734)|🌤|⛅️|🌥|☁️|🌦|🌧|⛈|🌩|🌨|❄️|(\u2744)|☃|(\u2603)️|⛄️|🌬|💨|💧|💦|☔️|☂️|🌊|🌫|🍏|🍎|🍐|🍊|🍋|🍌|🍉|🍇|🍓|🍈|🍒|🍑|🍍|🥭|🥥|🥝|🍅|🍆|🥑|🥦|🥒|🥬|🌶|🌽|🥕|🥔|🍠|🥐|🍞|🥖|🥨|🥯|🧀|🥚|🍳|🥞|🥓|🥩|🍗|🍖|🌭|🍔|🍟|🍕|🥪|🥙|🌮|🌯|🥗|🥘|🥫|🍝|🍜|🍲|🍛|🍣|🍱|🥟|🍤|🍙|🍚|🍘|🍥|🥮|🥠|🍢|🍡|🍧|🍨|🍦|🥧|🍰|🎂|🍮|🍭|🍬|🍫|🍿|🧂|🍩|🍪|🌰|🥜|🍯|🥛|🍼|☕️|🍵|🥤|🍶|🍺|🍻|🥂|🍷|🥃|🍸|🍹|🍾|🥄|🍴|🍽|🥣|🥡|🥢|⚽️|🏀|🏈|⚾️|🥎|🏐|🏉|🎾|🥏|🎱|🏓|🏸|🥅|🏒|🏑|🥍|🏏|⛳️|🏹|🎣|🥊|🥋|🎽|⛸|🥌|🛷|🛹|🎿|⛷|🏂|🏋️‍|🤼‍|🤸‍️|⛹️‍|🤺|🤾‍️|🏌️‍️|🏇|🧘‍️|🏄‍️|🏊‍️|🤽‍️|🚣‍|🧗‍️|🚵‍|🚴|🏆|🥇|🥈|🥉|🏅|🎖|🏵|🎗|🎫|🎟|🎪|🤹‍️|🤹|🎭|🎨|🎬|🎤|🎧|🎼|🎹|🥁|🎷|🎺|🎸|🎻|🎲|🧩|♟|🎯|🎳|🎮|🎰|🚗|🚕|🚙|🚌|🚎|🏎|🚓|🚑|🚒|🚐|🚚|🚛|🚜|🛴|🚲|🛵|🏍|🚨|🚔|🚍|🚘|🚖|🚡|🚠|🚟|🚃|🚋|🚞|🚝|🚄|🚅|🚈|🚂|🚆|🚇|🚊|🚉|✈️|🛫|🛬|🛩|💺|🛰|🚀|🛸|🚁|🛶|⛵️|🚤|🛥|🛳|⛴|🚢|⚓️|⛽️|🚧|🚦|🚥|🚏|🗺|🗿|🗽|🗼|🏰|🏯|🏟|🎡|🎢|🎠|⛲️|⛱|🏖|🏝|🏜|🌋|⛰|🏔|🗻|🏕|⛺️|🏠|🏡|🏘|🏚|🏗|🏭|🏢|🏬|🏣|🏤|🏥|🏦|🏨|🏪|🏫|🏩|💒|🏛|⛪️|🕌|🕍|🕋|⛩|🛤|🛣|🗾|🎑|🏞|🌅|🌄|🌠|🎇|🎆|🌇|🌆|🏙|🌃|🌌|🌉|🌁|🆓|📗|📕|⌚️|📱|📲|💻|⌨️|🖥|🖨|🖱|🖲|🕹|🗜|💽|💾|💿|📀|📼|📷|📸|📹|🎥|📽|🎞|📞|☎️|📟|📠|📺|📻|🎙|🎚|🎛|⏱|⏲|⏰|🕰|⌛️|⏳|📡|🔋|🔌|💡|🔦|🕯|🗑|🛢|💸|💵|💴|💶|💷|💰|💳|🧾|💎|⚖️|(\u2696)|🔧|🔨|⚒|(\u2692)|🛠|⛏|🔩|⚙️|⛓|🔫|💣|🔪|🗡|⚔|(\u2694)️|🛡|🚬|⚰️|(\u26B0)|⚱️|🏺|🧭|🧱|🔮|🧿|🧸|📿|💈|⚗️|🔭|🧰|🧲|🧪|🧫|🧬|🧯|🔬|🕳|💊|💉|🌡|🚽|🚰|🚿|🛁|🛀|🛀🏻|🛀🏼|🛀🏽|🛀🏾|🛀🏿|🧴|🧵|🧶|🧷|🧹|🧺|🧻|🧼|🧽|🛎|🔑|🗝|🚪|🛋|🛏|🛌|🖼|🛍|🧳|🛒|🎁|🎈|🎏|🎀|🎊|🎉|🧨|🎎|🏮|🎐|🧧|✉️|📩|📨|📧|💌|📥|📤|📦|🏷|📪|📫|📬|📭|📮|📯|📜|📃|📄|📑|📊|📈|📉|🗒|🗓|📆|📅|📇|🗃|🗳|🗄|📋|📁|📂|🗂|🗞|📰|📓|📔|📒|📕|📗|📘|📙|📚|📖|🔖|🔗|📎|🖇|📐|📏|📌|📍|✂️|🖊|🖋|✒️|🖌|🖍|📝|✏|(\u270F)️|🔍|🔎|🔏|🔐|🔒|🔓|❤|(\u2665)️|🧡|💛|💚|💙|💜|🖤|💔|❣️|💕|💞|💓|💗|💖|💘|💝|💟|☮️|✝️|☪️|🕉|☸️|✡️|🔯|🕎|☯️|☦️|🛐|⛎|♈️|♉️|♊️|♋️|♌️|♍️|♎️|♏️|♐️|♑️|♒️|♓️|🆔|⚛️|🉑|☢️|☣️|📴|📳|🈶|🈚️|🈸|🈺|🈷️|✴️|🆚|💮|🉐|㊙️|㊗️|🈴|🈵|🈹|🈲|🅰️|🅱️|🆎|🆑|🅾️|🆘|❌|⭕️|🛑|⛔️|📛|🚫|💯|💢|♨️|🚷|🚯|🚳|🚱|🔞|📵|🚭|❗️|❕|❓|❔|‼️|⁉️|🔅|🔆|〽️|⚠️|(\u26A0)|🚸|🔱|⚜️|🔰|♻️|✅|🈯️|💹|❇️|✳️|❎|🌐|💠|Ⓜ️|🌀|💤|🏧|🚾|♿️|🅿️|🈳|🈂️|🛂|🛃|🛄|🛅|🚹|🚺|🚼|🚻|🚮|🎦|📶|🈁|🔣|ℹ️|🔤|🔡|🔠|🆖|🆗|🆙|🆒|🆕|🆓|0️⃣|1️⃣|2️⃣|3️⃣|4️⃣|5️⃣|6️⃣|7️⃣|8️⃣|9️⃣|🔟|🔢|#️⃣|⏏️|▶️|⏸|⏯|⏹|⏺|⏭|⏮|⏩|⏪|⏫|⏬|◀️|🔼|🔽|➡️|⬅️|⬆️|⬇️|↗️|↘️|↙️|↖️|↕️|↔️|↪️|↩️|⤴️|⤵️|🔀|🔁|🔂|🔄|🔃|🎵|🎶|➕|➖|➗|✖️|♾|💲|💱|™️|©️|®️|〰️|➰|➿|🔚|🔙|🔛|🔝|🔜|✔️|☑|(\u2611)️|🔘|⚪️|⚫️|🔴|🔵|🔺|🔻|🔸|🔹|🔶|🔷|🔳|🔲|▪️|▫️|◾️|◽️|◼️|◻️|⬛️|⬜️|🔈|🔇|🔉|🔊|🔔|🔕|📣|📢|👁‍🗨|💬|💭|🗯|♠️|♣️|♥️|♦️|(\u2660)|(\u2661)|(\u2662)|(\u2663)|(\u2664)|(\u2666)|(\u2667)|🃏|🎴|🀄️|🕐|🕑|🕒|🕓|🕔|🕕|🕖|🕗|🕘|🕙|🕚|🕛|🕜|🕝|🕞|🕟|🕠|🕡|🕢|🕣|🕤|🕥|🕦|🕧|🏳️|🏴|🏁|🚩|🏳️‍|🌈|🏴|‍☠️|🎌|🥰|🥵|🥶|🥳|🥴|🥺|👨‍🦰|👩‍🦰|👨‍🦱|👩‍🦱|👨‍🦲|👩‍🦲|👨‍🦳|👩‍🦳|🦸️|🦹️|🦵|🦶|🦴|🦷|🥽|🥼|🥾|🥿|🦝|🦙|🦛|🦘|🦡|🦢|🦚|🦜|🦞|🦟|🦠|🥭|🥬|🥯|🧂|🥮|🧁|🧭|🧱|🛹|🧳|🧨|🧧|🥎|🥏|🥍|🧿|🧩|🧸|♟|🧮|🧾|🧰|🧲|🧪|🧫|🧬|🧯|🧴|🧵|🧶|🧷|🧹|🧺|🧻|🧼|🧽|♾|🏴‍|☠)"; 

  
      #--------------------------------------------------

# QUICK CORRECTIONS OF STANFORD TAGGER OUTPUT

  foreach $x (@word) {

    # Changes the two tags that have a problematic "$" symbol in the Stanford tagset
    if ($x =~ /PRP\$/) { $x =~ s/PRP./PRPS/; }
    if ($x =~ /WP\$/) { $x =~ s/WP./WPS/; }
  
  	# ELF: Correction of a few specific symbols identified as adjectives, cardinal numbers and foreign words by the Stanford Tagger.
  	# These are instead re-tagged as symbols so they don't count as tokens for the TTR and per-word normalisation basis.
  	# Removal of all LS (list symbol) tags except those that denote numbers
  	if ($x =~ /<_JJ|>_JJ|\^_FW|>_JJ|§_CD|=_JJ|\*_|\W+_LS|[a-zA-Z]+_LS/) { 
  		$x =~ s/_\w+/_SYM/; 
  		}
  		
  		
  	# ELF: Correction of cardinal numbers without spaces and list numbers as numbers rather than LS
  	# Removal of the LS (list symbol) tags that denote numbers
  	if ($x =~ /\b[0-9]+th_|\b[0-9]+nd_|\b[0-9]+rd_|[0-9]+_LS/) { 
  		$x =~ s/_\w+/_CD/; 
  		}  		

  	# ELF: Correct "innit" and "init" (frequently tagged as a noun by the Stanford Tagger) to pronoun "it" (these are later on also counted as question tags if they are followed by a question mark)
  	if ($x =~ /\binnit_/) { $x =~ s/_\w+/_PIT/; }
  	if ($x =~ /\binit_/) { $x =~ s/_\w+/_PIT/; }	

    
  # ADDITIONAL TAGS FOR INTERNET REGISTERS
    
  	# ELF: Tagging of emoji
  	if ($x =~ /($emoji)/) {
  		$x =~ s/_\w+/_EMO/;
    }
    
 	 # ELF: Tagging of hashtags
  	if ($x =~ /#\w{3,}/) {
  		$x =~ s/_\w+/_HST/;
    }
    
 	 # ELF: Tagging of web links
 	 # Note that the aim of this regex is *not* to extract all *valid* URLs but rather all strings that were intended to be a URL or a URL-like string!
 	 # Inspired by: https://mathiasbynens.be/demo/url-regex
 	 
 	 #https://www.youtube.com/watch?feature=player_NN&v=ithlg2geqyk_NNS
 	 #http://instagram.com/p/pbw_NN/_NN
	 #http://www.guydenning.org/writing/art_NN.htm_NN
	 #http://smarturl.it/poppy-single-itunes_FW

 	 
  	#if (($x =~ /\b(https?:\/\/www\.|https?:\/\/)?\w+([-\.\+_=&\/]{1}\w+)+\w+/i) ||
  	if (($x =~ /\b(https?:\/\/www\.|https?:\/\/)?\w+([\-\.\+=&\?]{1}\w+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?/i) ||
  		($x =~ /<link\/?>/) ||
  		($x =~ /\b\w+\.(com|net|co\.uk|au|us|gov|org)\b/)) {
  		$x =~ s/_[\w+\-\.\+=&\/\?]+/_URL/;
    }
    
  # BASIC TAG NEEDED FOR MORE COMPLEX TAGS
    # Negation
    if ($x =~ /\bnot_|\bn't_/i) {
      $x =~ s/_\w+/_XX0/;
    }
    
  }

# SLIGHTLY MORE COMPLEX CORRECTIONS OF STANFORD TAGGER OUTPUT

	# CORRECTION OF "TO" AS PREPOSITION 
	# ELF: Added "to" followed by a punctuation mark, e.g. "What are you up to?"
  
  	for ($j=0; $j<@word; $j++) {
  	
  	# Adding the most frequent emoticons to the emoji list
  	# Original list: https://repository.upenn.edu/pwpl/vol18/iss2/14/
  	# Plus crowdsourced other emoticons from colleagues on Twitter ;-)
  	
  	# For emoticons parsed as one token by the Stanford Tagger:
  	# The following were removed because they occur fairly frequently in academic writing ;-RRB-_ and -RRB-:_
  	if ($word[$j] =~ /\b(:-RRB-_|:d_|:-LRB-_|:p_|:--RRB-_|:-RSB-_|\bd:_|:'-LRB-_|:--LRB-_|:-d_|:-LSB-_|-LSB-:_|:-p_|:\/_|:P_|:D_|\b=-RRB-_|\b=-LRB-_|:-D_|:-RRB--RRB-_|:O_|:]_|:-LRB--LRB-_|:o_|:-O_|:-o_|;--RRB-_|;-\*|‘:--RRB--LRB-_|:-B_|\b8--RRB-_|=\|_|:-\|_|\b<3_|\bOo_|\b<\/3_|:P_|;P_|\bOrz_|\borz_|\bXD_|\bxD_|\bUwU_)/) {
        $word[$j] =~ s/_\w+/_EMO/;
  	}
  	
  	# For emoticons where each character is parsed as an individual token.
  	# The aim here is to only have one EMO tag per emoticon and, if there are any letters in the emoticon, for the EMO tag to be placed on the letter to overwrite any erroneous NN, FW or LS tags from the Stanford Tagger:
    if (($word[$j] =~ /:_\W+|;_\W+|=_/ && $word[$j+1] =~ /\/_\W+|\b\\_\W+/) ||
    	#($word[$j] =~ /:_|;_|=_/ && $word[$j+1] =~ /-LRB-|-RRB-|-RSB-|-LSB-/) || # This line can be used to improve recall when tagging internet registers with lots of emoticons but is not recommended for a broad range of registers since it will cause a serious drop in precision in registers with a lot of punctuation, e.g., academic English.
   		($word[$j] =~ /\bd_|\bp_/i && $word[$j+1] =~ /\b:_/) ||
   		($word[$j] =~ /:_\W+|;_\W+|\b8_/ && $word[$j+1] =~ /\b-_|'_|-LRB-|-RRB-/ && $word[$j+2] =~ /-LRB-|-RRB-|\b\_|\b\/_|\*_/)) {
        $word[$j] =~ s/_\w+/_EMO/;
        $word[$j] =~ s/_(\W+)/_EMO/;
    }  
      
  	# For other emoticons where each character is parsed as an individual token and the letters occur in +1 position.
  	
    if (($word[$j] =~ /<_/ && $word[$j+1] =~ /\b3_/) ||
    	#($word[$j] =~ /:_|;_|=_/ && $word[$j+1] =~ /\bd_|\bp_|\bo_|\b3_/i) || # # These two lines may be used to improve recall when tagging internet registers with lots of emoticons but is not recommended for a broad range of registers since it will cause a serious drop in precision in registers with a lot of punctuation, e.g., academic English.
   		#($word[$j] =~ /-LRB-|-RRB-|-RSB-|-LSB-/ && $word[$j+1] =~ /:_|;_/) || 
   		($word[$j-1] =~ />_/ && $word[$j] =~ /:_/ && $word[$j+1] =~ /-LRB-|-RRB-|\bD_/) ||
   		($word[$j] =~ /\^_/ && $word[$j+1] =~ /\^_/) ||
   		($word[$j] =~ /:_\W+/ && $word[$j+1] =~ /\bo_|\b-_/i && $word[$j+2] =~ /-LRB-|-RRB-/) ||
   		($word[$j-1] =~ /<_/ && $word[$j] =~ /\/_/ && $word[$j+1] =~ /\b3_/) ||
   		($word[$j-1] =~ /:_\W+|\b8_|;_\W+|=_/ && $word[$j] =~ /\b-_|'_|-LRB-|-RRB-/ && $word[$j+1] =~ /\bd_|\bp_|\bo_|\bb_|\b\|_|\b\/_/i && $word[$j+2] !~ /-RRB-/)) {
        $word[$j+1] =~ s/_\w+/_EMO/;
        $word[$j+1] =~ s/_(\W+)/_EMO/;
    }    
    
    # Correct double punctuation such as ?! and !? (often tagged by the Stanford Tagger as a noun or foreign word) 
    if ($word[$j] =~ /[\?\!]{2,15}/) {
     		 $word[$j] =~ s/_(\W+)/_\./;
     		 $word[$j] =~ s/_(\w+)/_\./;
    }
    
    if ($word[$j] =~ /\bto_/i && $word[$j+1] =~ /_IN|_CD|_DT|_JJ|_WPS|_NN|_NNP|_PDT|_PRP|_WDT|(\b($wp))|_WRB|_\W/i) {
     	 $word[$j] =~ s/_\w+/_IN/;
    }
    
    # ELF: correcting "I dunno"
    if ($word[$j] =~ /\bdu_/i && $word[$j+1] =~ /\bn_/ && $word[$j+2] =~ /\bno_/) { 
    	$word[$j] =~ s/_\w+/_VPRT/;
    	$word[$j+1] =~ s/_\w+/_XX0/;
    	$word[$j+2] =~ s/_\w+/_VB/;
    }
    
    if ($word[$j] =~ /\bhave_VB/i && $word[$j+1] =~ /_PRP/ && $word[$j+2] =~ /_VBN|_VBD/) {
    	$word[$j] =~ s/_\w+/_VPRT/;
    }

	# ELF: Correction of falsely tagged "'s" following "there". 
    
    if ($word[$j-1] =~ /\bthere_EX/i && $word[$j] =~ /_POS/) {
      $word[$j] =~ s/_\w+/_VPRT/;
    }
    
    # ELF: Correction of most problematic spoken language particles
    # ELF: DMA is a new variable. It is important for it to be high up because lots of DMA's are marked as nouns by the Stanford Tagger which messes up other variables further down the line otherwise. More complex DMAs are further down.
    if ($word[$j] =~ /\bactually_|\banyway|\bdamn_|\bgoodness_|\bgosh_|\byeah_|\byep_|\byes_|\bnope_|\bright_UH|\bwhatever_|\bdamn_RB|\blol_|\bIMO_|\bomg_|\bwtf_/i) {
      $word[$j] =~ s/_\w+/_DMA/;
    }

    # ELF: FPUH is a new variable.
    # ELF: tags interjections and filled pauses.
    if ($word[$j] =~ /\baw+_|\bow_|\boh+_|\beh+_|\ber+_|\berm+_|\bmm+_|\bum+_|\b[hu]{2,}_|\bmhm+|\bhi+_|\bhey+_|\bby+e+_|\b[ha]{2,}_|\b[he]{2,}_|\b[wo]{3,}p?s*_|\b[oi]{2,}_|\bouch_/i) {
      $word[$j] =~ s/_(\w+)/_FPUH/;
    }
    # Also added "hm+" on Peter's suggestion but made sure that this was case sensitive to avoid mistagging Her Majesty ;-)
    if ($word[$j] =~ /\bhm+|\bHm+/) {
      $word[$j] =~ s/_(\w+)/_FPUH/;
    }  
    
    #--------------------------------------------------
    
      
# ELF: Added a new variable for "so" as tagged as a preposition (IN) or adverb (RB) by the Stanford Tagger because it most often does not seem to be a preposition/conjunct (but rather a filler, amplifier, etc.) and should therefore not be added to the preposition count.
  
    if ($word[$j] =~ /\bso_IN|\bso_RB/i) {
      $word[$j] =~ s/_\w+/_SO/;
    }
    
# Tags quantifiers 
# ELF: Note that his variable is used to identify several other features. 
# ELF: added "any", "lots", "loada" and "a lot of" and gave it its own loop because it is now more complex and must be completed before the next set of for-loops. Also added "most" except when later overwritten as an EMPH.
# ELF: Added "more" and "less" when tagged by the Stanford Tagger as adjectives (JJ.*). As adverbs (RB), they are tagged as amplifiers (AMP) and downtoners (DWT) respectively.
# ELF: Also added "load(s) of" and "heaps of" on DS's recommendation

      
    # ELF: Getting rid of the Stanford Tagger predeterminer (PDT) category and now counting all those as quantifiers (QUAN)
    if (($word[$j] =~ /_PDT/i) || 
    ($word[$j] =~ /\ball_|\bany_|\bboth_|\beach_|\bevery_|\bfew_|\bhalf_|\bmany_|\bmore_JJ|\bmuch_|\bplenty_|\bseveral_|\bsome_|\blots_|\bloads_|\bheaps_|\bless_JJ|\bloada_|\bwee_/i)||
    
    ($word[$j] =~ /\bload_/i && $word[$j+1] =~ /\bof_/i) ||
    ($word[$j] =~ /\bmost_/i && $word[$j+1] =~ /\bof_|\W+/i) ||
    ($word[$j-1] =~ /\ba_/i && $word[$j] =~ /\blot_|\bbit_/i)) { # ELF: Added "a lot (of)" and removed NULL tags
        $word[$j] =~ s/_\w+/_QUAN/;

  	}
  }
  
  #---------------------------------------------------

  # COMPLEX TAGS
  for ($j=0; $j<@word; $j++) {

  #---------------------------------------------------
 
  # ELF: New variable. Tags the remaining pragmatic and discourse markers 
  # The starting point was Stenström's (1994:59) list of "interactional signals and discourse markers" (cited in Aijmer 2002: 2) 
  # --> but it does not include "now" (since it's already a time adverbial), "please" (included in politeness), "quite" or "sort of" (hedges). 
  # I also added: "nope", "I guess", "mind you", "whatever" and "damn" (if not a verb and not already tagged as an emphatic).
    
    if (($word[$j] =~ /\bno_/i && $word[$j] !~ /_VB/ && $word[$j+1] !~ /_J|_NN/) || # This avoid a conflict with the synthetic negation variable and leaves the "no" in "I dunno" as a present tense verb form and "no" from "no one".
      ($word[$j-1] =~ /_\W|FPUH_/ && $word[$j] =~ /\bright_|\bokay_|\bok_/i) || # Right and okay immediately proceeded by a punctuation mark or a filler word
      ($word[$j-1] !~ /\bas_|\bhow_|\bvery_|\breally_|\bso_|\bquite_|_V/i && $word[$j] =~ /\bwell_JJ|\bwell_RB|\bwell_NNP|\bwell_UH/i && $word[$j+1] !~ /_JJ|_RB/) || # Includes all forms of "well" except as a singular noun assuming that the others are mistags of DMA well's by the Stanford Tagger.
      ($word[$j-1] !~ /\bmakes_|\bmake_|\bmade_|\bmaking_|\bnot|_\bfor_|\byou_|\b($be)/i && $word[$j] =~ /\bsure_JJ|\bsure_RB/i) || # This excludes MAKE sure, BE sure, not sure, and for sure
		($word[$j-1] =~ /\bof_/i && $word[$j] =~ /\bcourse_/i) ||
    	($word[$j-1] =~ /\ball_/i && $word[$j] =~ /\bright_/i) ||
    	($word[$j] =~ /\bmind_/i && $word[$j+1] =~ /\byou_/i)) { 
     
      $word[$j] =~ s/_\w+/_DMA/;
    }
      
    #--------------------------------------------------

    # Tags predicative adjectives 
    # ELF: added list of stative verbs other than BE. Also the last two if-statements to account for lists of adjectives separated by commas and Oxford commas before "and" at the end of a list. Removed the bit about not preceding an adverb.
    
   # if (($word[$j-1] =~ /\b($be)|\b($v_stative)_V/i && $word[$j] =~ /_JJ|\bok_|\bokay_/i && $word[$j+1] !~ /_JJ|_NN/) || # I'm hungry
    #	($word[$j-2] =~ /\b($be)|\b($v_stative)_V/i && $word[$j-1] =~ /_RB|\bso_|_EMPH|_XX0/i && $word[$j] =~ /_JJ|\bok_|\bokay_/i && $word[$j+1] !~ /_JJ|_NN/) || # I'm so|not hungry
    #	($word[$j] =~ /_JJ|ok_|okay_/i && $word[$j+1] =~ /_\./) || # Amazing! Oh nice.
    #	($word[$j-3] =~ /\b($be)|\b($v_stative)_V/i && $word[$j-1] =~ /_XX0|_RB|_EMPH/ && $word[$j] =~ /_JJ/ && $word[$j+1] !~ /_JJ|_NN/)) # I'm just not hungry
    #	{
     #   $word[$j] =~ s/_\w+/_JPRED/;
    #}
  #  if (($word[$j-2] =~ /_JPRED/ && $word[$j-1] =~ /\band_/i && $word[$j] =~ /_JJ/) ||
   # 	($word[$j-2] =~ /_JPRED/ && $word[$j-1] =~ /,_,/ && $word[$j] =~ /_JJ/) ||
    #	($word[$j-3] =~ /_JPRED/ && $word[$j-2] =~ /,_,/ && $word[$j-1] =~ /\band_/ && $word[$j] =~ /_JJ/)) {
     #   $word[$j] =~ s/_\w+/_JPRED/;
    #}
    
    #--------------------------------------------------

    # Tags attribute adjectives (JJAT) (see additional loop further down the line for additional JJAT cases that rely on these JJAT tags)

    if (($word[$j] =~ /_JJ/ && $word[$j+1] =~ /_JJ|_NN|_CD/) ||
		($word[$j-1] =~ /_DT/ && $word[$j] =~ /_JJ/)) {
        $word[$j] =~ s/_\w+/_JJAT/;
    }
    #----------------------------------------------------
    #Shakir: Add two sub classes of attributive and predicative adjectives. The predicative counterparts should not have a TO or THSC afterwards
    if ($word[$j] =~ /\b($jj_att_other)_(JJAT|JJPR)/i && $word[$j+1] !~ /to_|_THSC/) {
        $word[$j] =~ s/_(\w+)/_$1 JJATDother/;
    }

    if ($word[$j] =~ /\b($jj_epist_other)_(JJAT|JJPR)/i && $word[$j+1] !~ /to_|_THSC/) {
        $word[$j] =~ s/_(\w+)/_$1 JJEPSTother/;
    }    
    #
    if ($word[$j] =~ /\b(JJATDother|JJEPSTother)_J/i && $word[$j+1] !~ /to_|_THSC/ && $word[$j] !~ / /) {
        $word[$j] =~ s/_(\w+)/_$1 JJSTNCAllother/;
    }
    #----------------------------------------------------    
    # Manually add okay as a predicative adjective (JJPR) because "okay" and "ok" are often tagged as foreign words by the Stanford Tagger. All other predicative adjectives are tagged at the very end.
    
    if ($word[$j-1] =~ /\b($be)/i && $word[$j] =~ /\bok_|okay_/i) {
        $word[$j] =~ s/_\w+/_JJPR/;
    }

    #---------------------------------------------------
   
    # Tags elaborating conjunctions (ELAB)
    # ELF: This is a new variable.
    
    # ELF: added the exception that "that" should not be a determiner. Also added "in that" and "to the extent that" on DS's advice.  
    
    if (($word[$j-1] =~ /\bsuch_/i && $word[$j] =~ /\bthat_/ && $word[$j] !~ /_DT/) ||
      ($word[$j-1] =~ /\bsuch_|\binasmuch__|\bforasmuch_|\binsofar_|\binsomuch/i && $word[$j] =~ /\bas_/) ||
      ($word[$j-1] =~ /\bin_IN/i && $word[$j] =~ /\bthat_/ && $word[$j] !~ /_DT/) ||
      ($word[$j-3] =~ /\bto_/i && $word[$j-2] =~ /\bthe_/ && $word[$j-1] =~ /\bextent_/ && $word[$j] =~ /\bthat_/) ||
      ($word[$j-1] =~ /\bin_/i && $word[$j] =~ /\bparticular_|\bconclusion_|\bsum_|\bsummary_|\bfact_|\bbrief_/i) ||
      ($word[$j-1] =~ /\bto_/i && $word[$j] =~ /\bsummarise_|\bsummarize_/i && $word[$j] =~ /,_/) ||
      ($word[$j-1] =~ /\bfor_/i && $word[$j] =~ /\bexample_|\binstance_/i) ||
      ($word[$j] =~ /\bsimilarly_|\baccordingly_/i && $word[$j+1] =~ /,_/) ||
      ($word[$j-2] =~ /\bin_/i && $word[$j-1] =~ /\bany_/i && $word[$j] =~ /\bevent_|\bcase_/i) ||
      ($word[$j-2] =~ /\bin_/i && $word[$j-1] =~ /\bother_/i && $word[$j] =~ /\bwords_/)) {
        $word[$j] =~ s/_(\w+)/_$1 ELAB/;
    }
    
    if ($word[$j] =~ /\beg_|\be\.g\._|etc\.?_|\bi\.e\._|\bcf\.?_|\blikewise_|\bnamely_|\bviz\.?_/i) {
        $word[$j] =~ s/_\w+/_ELAB/;
    }
    

    #---------------------------------------------------
   
    # Tags coordinating conjunctions (CC)
    # ELF: This is a new variable.
    # ELF: added as well as, as well, in fact, accordingly, thereby, also, by contrast, besides, further_RB, in comparison, instead (not followed by "of").

    if (($word[$j] =~ /\bwhile_IN|\bwhile_RB|\bwhilst_|\bwhereupon_|\bwhereas_|\bwhereby_|\bthereby_|\balso_|\bbesides_|\bfurther_RB|\binstead_|\bmoreover_|\bfurthermore_|\badditionally_|\bhowever_|\binstead_|\bibid\._|\bibid_|\bconversly_/i) || 
      ($word[$j] =~ /\binasmuch__|\bforasmuch_|\binsofar_|\binsomuch/i && $word[$j+1] =~ /\bas_/i) ||
      ($word[$j-1] =~ /_\W/i && $word[$j] =~ /\bhowever_/i) ||
      ($word[$j+1] =~ /_\W/i && $word[$j] =~ /\bhowever_/i) ||
      ($word[$j-1] =~ /\bor_/i && $word[$j] =~ /\brather_/i) ||
      ($word[$j-1] !~ /\bleast_/i && $word[$j] =~ /\bas_/i && $word[$j+1] =~ /\bwell_/i) || # Excludes "as least as well" but includes "as well as"
      ($word[$j-1] =~ /_\W/ && $word[$j] =~ /\belse_|\baltogether_|\brather_/i)) {
        $word[$j] =~ s/_\w+/_CC/;
    }
    
    if (($word[$j-1] =~ /\bby_/i && $word[$j] =~ /\bcontrast_|\bcomparison_/i) ||
      ($word[$j-1] =~ /\bin_/i && $word[$j] =~ /\bcomparison_|\bcontrast_|\baddition_/i) ||
      ($word[$j-2] =~ /\bon_/i && $word[$j-1] =~ /\bthe_/ && $word[$j] =~ /\bcontrary_/i) ||
      ($word[$j-3] =~ /\bon_/i && $word[$j-2] =~ /\bthe_/ && $word[$j-1] =~ /\bone_|\bother_/i && $word[$j] =~ /\bhand_/i)) {
        $word[$j] =~ s/_(\w+)/_$1 CC/;
    }

    #---------------------------------------------------
    
    # Tags causal conjunctions     
    # ELF added: cos, cus, coz, cuz and 'cause (a form spotted in one textbook of the TEC!) plus all the complex forms below.
    
    if (($word[$j] =~ /\bbecause_|\bcos_|\bcos\._|\bcus_|\bcuz_|\bcoz_|\b'cause_/i) ||
    	($word[$j] =~ /\bthanks_/i && $word[$j+1] =~ /\bto_/i) ||
        ($word[$j] =~ /\bthus_/i && $word[$j+1] !~ /\bfar_/i)) {
        $word[$j] =~ s/_\w+/_CUZ/;
    	}
    	
    if (($word[$j-1] =~ /\bin_/i && $word[$j] =~ /\bconsequence_/i) ||
    	($word[$j] =~ /\bconsequently_|\bhence_|\btherefore_/i) ||
    	($word[$j-1] =~ /\bsuch_|\bso_/i && $word[$j] =~ /\bthat_/ && $word[$j] !~ /_DT/) ||
    	($word[$j-2] =~ /\bas_/i && $word[$j-1] =~ /\ba_/i && $word[$j] =~ /\bresult_|\bconsequence_/i) ||
    	($word[$j-2] =~ /\bon_/i && $word[$j-1] =~ /\baccount_/i && $word[$j] =~ /\bof_/i) ||
    	($word[$j-2] =~ /\bfor_/i && $word[$j-1] =~ /\bthat_|\bthis_/i && $word[$j] =~ /\bpurpose_/i) ||
    	($word[$j-2] =~ /\bto_/i && $word[$j-1] =~ /\bthat_|\bthis_/i && $word[$j] =~ /\bend_/i)) {
        	$word[$j] =~ s/_(\w+)/_$1 CUZ/;
    	}

    #---------------------------------------------------

    # Tags conditional conjunctions
    # ELF: added "lest" on DS's suggestion. Added "whether" on PU's suggestion.
    	
	if ($word[$j] =~ /\bif_|\bunless_|\blest_|\botherwise_|\bwhether_/i) {
        	$word[$j] =~ s/_\w+/_COND/;
		}
		
	if (($word[$j-2] =~ /\bas_/i && $word[$j-1] =~ /\blong_/ && $word[$j] =~ /\bas_/) ||
		($word[$j-2] =~ /\bin_/i && $word[$j-1] =~ /\bthat_/ && $word[$j] =~ /\bcase_/)) {
        $word[$j] =~ s/_(\w+)/_$1 COND/;
    	}

    #---------------------------------------------------

    # Tags emphatics 
    # ELF: added "such an" and ensured that the indefinite articles in "such a/an" are not tagged as NULL as was the case in Nini's script. Removed "more".
    # Added: so many, so much, so little, so + VERB, damn + ADJ, least, bloody, fuck, fucking, damn, super and dead + ADJ.
    # Added a differentiation between "most" as as QUAN ("most of") and EMPH.
    # Improved the accuracy of DO + verb by specifying a base form (_VB) so as to avoid: "Did they do_EMPH stuffed_VBN crust?".
    if (($word[$j] =~ /\bmost_DT/i) ||
    	($word[$j] =~ /\breal__|\bdead_|\bdamn_/i && $word[$j+1] =~ /_J/) ||
    	($word[$j-1] =~ /\bat_|\bthe_/i && $word[$j] =~ /\bleast_|\bmost_/) ||
    	($word[$j] =~ /\bso_/i && $word[$j+1] =~ /_J|\bmany_|\bmuch_|\blittle_|_RB/i) ||
      	($word[$j] =~ /\bfar_/i && $word[$j+1] =~ /_J|_RB/ && $word[$j-1] !~ /\bso_|\bthus_/i) ||
      	($word[$j-1] !~ /\bof_/i && $word[$j] =~ /\bsuch_/i && $word[$j+1] =~ /\ba_|\ban_/i)) {
        	$word[$j] =~ s/_\w+/_EMPH/;
    	}
    
    if (($word[$j] =~ /\bloads_/i && $word[$j+1] !~ /\bof_/i) ||
      	($word[$j] =~ /\b($do)/i && $word[$j+1] =~ /_VB\b/) ||
    	($word[$j] =~ /\bjust_|\bbest_|\breally_|\bmost_JJ|\bmost_RB|\bbloody_|\bfucking_|\bfuck_|\bshit_|\bsuper_/i) ||
    	($word[$j] =~ /\bfor_/i && $word[$j+1] =~ /\bsure_/i)) { 
        	$word[$j] =~ s/_(\w+)/_$1 EMPH/;
    	}

    #---------------------------------------------------

    # Tags phrasal coordination with "and", "or" and "nor". 
    # ELF: Not currently in use due to relatively low precision and recall (see tagger performance evaluation).
    #if (($word[$j] =~ /\band_|\bor_|&_|\bnor_/i) &&
     # (($word[$j-1] =~ /_RB/ && $word[$j+1] =~ /_RB/) ||
      #($word[$j-1] =~ /_J/ && $word[$j+1] =~ /_J/) ||
      #($word[$j-1] =~ /_V/ && $word[$j+1] =~ /_V/) ||
      #($word[$j-1] =~ /_CD/ && $word[$j+1] =~ /_CD/) ||
      #($word[$j-1] =~ /_NN/ && $word[$j+1] =~ /_NN|whatever_|_DT/))) {
       #   $word[$j] =~ s/_\w+/_PHC/;
    #}
    
    #---------------------------------------------------
    
        # Tags auxiliary DO ELF: I added this variable and removed Nini's old pro-verb DO variable. Later on, all DO verbs not tagged as DOAUX here are tagged as ACT.
    if ($word[$j] =~ /\bdo_V|\bdoes_V|\bdid_V/i && $word[$j-1] !~ /to_TO/) { # This excludes DO + VB\b which have already been tagged as emphatics (DO_EMPH) and "to do" constructions
      if (($word[$j+2] =~ /_VB\b/) || # did you hurt yourself? Didn't look? 
        ($word[$j+3] =~ /_VB\b/) || # didn't it hurt?
        ($word[$j+1] =~ /_\W/) || # You did?
        ($word[$j+1] =~ /\bI_|\byou_|\bhe_|\bshe_|\bit_|\bwe_|\bthey_|_XX0/i && $word[$j+2] =~ /_\.|_VB\b/) || # ELF: Added to include question tags such as: "do you?"" or "He didn't!""
        ($word[$j+1] =~ /_XX0/ && $word[$j+2] =~ /\bI_|\byou_|\bhe_|\bshe_|\bit_|\bwe_|\bthey_|_VB\b/i) || # Allows for question tags such as: didn't you? as well as negated forms such as: did not like
        ($word[$j+1] =~ /\bI_|\byou_|\bhe_|\bshe_|\bit_|\bwe_|\bthey_/i && $word[$j+3] =~ /\?_\./) || # ELF: Added to include question tags such as: did you not? did you really?
        ($word[$j-1] =~ /(\b($wp))|(\b$who)|(\b$whw)/i)) {
          $word[$j] =~ s/_(\w+)/_$1 DOAUX/;
      }
    }
    
    #---------------------------------------------------    

    # Tags WH questions
    # ELF: rewrote this new operationalisation because Biber/Nini's code relied on a full stop appearing before the question word. 
    # This new operationalisation requires a question word (from a much shorter list taken from the COBUILD that Nini's/Biber's list) that is not followed by another question word and then a question mark within 15 words. 
    if (($word[$j] =~ /\b$whw/i && $word[$j+1] =~ /\?_\./)  ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+2] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+3] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+4] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+5] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+6] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+7] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+8] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+9] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+10] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+11] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+12] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+13] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+14] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+15] =~ /\?_\./) ||
    	($word[$j] =~ /\b$whw/i && $word[$j+1] !~ /\b$whw/i && $word[$j+16] =~ /\?_\./)) {
          $word[$j] =~ s/(\w+)_(\w+)/$1_WHQU/;
    }
    
    #---------------------------------------------------    
  	# Tags yes/no inverted questions (YNQU)
  	# ELF: New variable
  	# Note that, at this stage in the script, DT still includes demonstrative pronouns which is good. Also _P, at this stage, only includes PRP, and PPS (i.e., not yet any of the new verb variables which should not be captured here)
  	
  	if (($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT/ && $word[$j+3] =~ /\?_\./) ||  # Are they there? It is him?
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+4] =~ /\?_\./) || # Can you tell him?
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+5] =~ /\?_\./) || # Did her boss know that?
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+6] =~ /\?_\./) ||
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+7] =~ /\?_\./) ||
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+8] =~ /\?_\./) ||
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+9] =~ /\?_\./) ||
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+10] =~ /\?_\./) ||
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+11] =~ /\?_\./) ||
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+12] =~ /\?_\./) ||
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+13] =~ /\?_\./) ||
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+14] =~ /\?_\./) ||
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+15] =~ /\?_\./) ||
  		($word[$j-2] !~ /_WHQU|YNQU/ && $word[$j-1] !~ /_WHQU|YNQU/ && $word[$j] =~ /\b($be)|\b($have)|\b($do)|_MD/i && $word[$j+1] =~ /_P|_NN|_DT|_XX0/ && $word[$j+16] =~ /\?_\./)) {
      		$word[$j] =~ s/_(\w+)/_$1 YNQU/;
    }

    #---------------------------------------------------
    
    # Tags passives 
    # ELF: merged Biber's BYPA and PASS categories together into one and changed the original coding procedure on its head: this script now tags the past participles rather than the verb BE. It also allows for mistagging of -ed past participle forms as VBD by the Stanford Tagger.
    # ELF: I am including most "'s_VBZ" as a possible form of the verb BE here but later on overriding many instances as part of the PEAS variable.    
    
    if ($word[$j] =~ /_VBN|ed_VBD|en_VBD/) { # Also accounts for past participle forms ending in "ed" and "en" mistagged as past tense forms (VBD) by the Stanford Tagger
    
      if (($word[$j-1] =~ /\b($be)/i) || # is eaten 
      	#($word[$j-1] =~ /s_VBZ/i && $word[$j+1] =~ /\bby_/) || # This line enables the passive to be preferred over present perfect if immediately followed by a "by"
      	($word[$j-1] =~ /_RB|_XX0|_CC/ && $word[$j-2] =~ /\b($be)/i) || # isn't eaten 
        ($word[$j-1] =~ /_RB|_XX0|_CC/ && $word[$j-2] =~ /_RB|_XX0/ && $word[$j-3] =~ /\b($be)/i && $word[$j-3] !~ /\bs_VBZ/) || # isn't really eaten
        ($word[$j-1] =~ /_NN|_PRP|_CC/ && $word[$j-2] =~ /\b($be)/i)|| # is it eaten
        ($word[$j-1] =~ /_RB|_XX0|_CC/ && $word[$j-2] =~ /_NN|_PRP/ && $word[$j-3] =~ /\b($be)/i && $word[$j-3] !~ /\bs_VBZ/)) { # was she not failed?
            $word[$j] =~ s/_\w+/_PASS/;
      }
    }

	# ELF: Added a new variable for GET-passives
    if ($word[$j] =~ /_VBD|_VBN/) {
      if (($word[$j-1] =~ /\bget_V|\bgets_V|\bgot_V|\bgetting_V/i) ||
        ($word[$j-1] =~ /_NN|_PRP/ && $word[$j-2] =~ /\bget_V|\bgets_V|\bgot_V|\bgetting_V/i) || # She got it cleaned
        ($word[$j-1] =~ /_NN/ && $word[$j-2] =~ /_DT|_NN/ && $word[$j-3] =~ /\bget_V|\bgets_V|\bgot_V|\bgetting_V/i)) { # She got the car cleaned
    	$word[$j] =~ s/_\w+/_PGET/;
      }
    }
    

     #---------------------------------------------------
    
    # ELF: Added the new variable GOING TO, which allows for one intervening word between TO and the infinitive
    # Shakir: Added case insensitive flag for going and gon
    if (($word[$j] =~ /\bgoing_VBG/i && $word[$j+1] =~ /\bto_TO/ && $word[$j+2] =~ /\_VB/) ||
      ($word[$j] =~ /\bgoing_VBG/i && $word[$j+1] =~ /\bto_TO/ && $word[$j+3] =~ /\_VB/) ||
      ($word[$j] =~ /\bgon_VBG/i && $word[$j+1] =~ /\bna_TO/ && $word[$j+2] =~ /\_VB/) ||
      ($word[$j] =~ /\bgon_VBG/i && $word[$j+1] =~ /\bna_TO/ && $word[$j+3] =~ /\_VB/)) {
      $word[$j] =~ s/_\w+/_GTO/;
    }
    #----------------------------------------------------
    #Shakir: to and split infin clauses followed by vb adj nouns.
    if (($word[$j-1] =~ /\b($to_vb_desire)_V/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_desire)_V/i && $word[$j] =~ /\bto_/ && $word[$j+2] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_desire)_V/i && $word[$j] =~ /\bna_TO/ && $word[$j+1] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_desire)_V/i && $word[$j] =~ /\bna_TO/ && $word[$j+2] =~ /\_V/)) {
      $word[$j] =~ s/_(\w+)/_$1 ToVDSR/;
    }

    if (($word[$j-1] =~ /\b($to_vb_effort)_V/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_effort)_V/i && $word[$j] =~ /\bto_/ && $word[$j+2] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_effort)_V/i && $word[$j] =~ /\bna_TO/ && $word[$j+1] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_effort)_V/i && $word[$j] =~ /\bna_TO/ && $word[$j+2] =~ /\_V/)) {
      $word[$j] =~ s/_(\w+)/_$1 ToVEFRT/;
    }

    if (($word[$j-1] =~ /\b($to_vb_prob)_V/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_prob)_V/i && $word[$j] =~ /\bto_/ && $word[$j+2] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_prob)_V/i && $word[$j] =~ /\bna_TO/ && $word[$j+1] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_prob)_V/i && $word[$j] =~ /\bna_TO/ && $word[$j+2] =~ /\_V/)) {
      $word[$j] =~ s/_(\w+)/_$1 ToVPROB/;
    }

    if (($word[$j-1] =~ /\b($to_vb_speech)_V/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_speech)_V/i && $word[$j] =~ /\bto_/ && $word[$j+2] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_speech)_V/i && $word[$j] =~ /\bna_TO/ && $word[$j+1] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_speech)_V/i && $word[$j] =~ /\bna_TO/ && $word[$j+2] =~ /\_V/)) {
      $word[$j] =~ s/_(\w+)/_$1 ToVSPCH/;
    }

    if (($word[$j-1] =~ /\b($to_vb_mental)_V/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_mental)_V/i && $word[$j] =~ /\bto_/ && $word[$j+2] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_mental)_V/i && $word[$j] =~ /\bna_TO/ && $word[$j+1] =~ /\_V/) ||
      ($word[$j-1] =~ /\b($to_vb_mental)_V/i && $word[$j] =~ /\bna_TO/ && $word[$j+2] =~ /\_V/)) {
      $word[$j] =~ s/_(\w+)/_$1 ToVMNTL/;
    }

    if ($word[$j-1] =~ /\b($to_jj_certain)_J/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) {
      $word[$j] =~ s/_(\w+)/_$1 ToJCRTN/;
    }

    if ($word[$j-1] =~ /\b($to_jj_able)_J/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) {
      $word[$j] =~ s/_(\w+)/_$1 ToJABL/;
    }

    if ($word[$j-1] =~ /\b($to_jj_affect)_J/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) {
      $word[$j] =~ s/_(\w+)/_$1 ToJEFCT/;
    }

    if ($word[$j-1] =~ /\b($to_jj_ease)_J/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) {
      $word[$j] =~ s/_(\w+)/_$1 ToJEASE/;
    }

    if ($word[$j-1] =~ /\b($to_jj_eval)_J/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) {
      $word[$j] =~ s/_(\w+)/_$1 ToJEVAL/;
    }        
    #Shakir: sums of that clauses for vb, jj, nn and all to be used if original are too low freq
    if ($word[$j] =~ / (ToVDSR|ToVEFRT|ToVPROB|ToVSPCH|ToVMNTL)/) {
      $word[$j] =~ s/_(\w+)/_$1 ToVSTNCAll/;
      }
    if ($word[$j] =~ / (ToJCRTN|ToJABL|ToJEFCT|ToJEASE|ToJEVAL)/) {
      $word[$j] =~ s/_(\w+)/_$1 ToJSTNCAll/;
      }
    #Shakir: all to vb stance excep verbs of desive which are frequent mainly due to want to constructions
    if ($word[$j] =~ / (ToVEFRT|ToVPROB|ToVSPCH|ToVMNTL)/) {
      $word[$j] =~ s/_(\w+)/_$1 ToVSTNCother/;
      }    
    if ($word[$j-1] =~ /\b($to_nn_stance_all)_N/i && $word[$j] =~ /\bto_/ && $word[$j+1] =~ /\_V/) {
      $word[$j] =~ s/_(\w+)/_$1 ToNSTNC/;
    }
    if ($word[$j] =~ / (ToVDSR|ToVEFRT|ToVPROB|ToVSPCH|ToVMNTL|ToJCRTN|ToJABL|ToJEFCT|ToJEASE|ToJEVAL|ToNSTNC)/) {
      $word[$j] =~ s/_(\w+)/_$1 ToSTNCAll/;
    }
    #----------------------------------------------------

    # Tags synthetic negation 
    # ELF: I'm merging this category with Biber's original analytic negation category (XX0) so I've had to move it further down in the script so it doesn't interfere with other complex tags
    if (($word[$j] =~ /\bno_/i && $word[$j+1] =~ /_J|_NN/) ||
      ($word[$j] =~ /\bneither_/i) ||
      ($word[$j] =~ /\bnor_/i)) {
        $word[$j] =~ s/_(\w+)/_XX0/;
    }
    # Added a loop to tag "no one" and "each other" as a QUPR
    if (($word[$j] =~ /\bno_/i && $word[$j+1] =~ /\bone_/) ||
    	($word[$j-1] =~ /\beach_/i && $word[$j] =~ /\bother_/)) {
    	$word[$j+1] =~ s/_(\w+)/_QUPR/;
    }

    #---------------------------------------------------

    # Tags split infinitives
    # ELF: merged this variable with split auxiliaries due to very low counts. Also removed "_AMPLIF|_DOWNTON" from these lists which Nini had but which made no sense because AMP and DWNT are a) tagged with shorter acronyms and b) this happens in future loops so RB does the job here. However, RB does not suffice for "n't" and not so I added _XX0 to the regex.
     
    if (($word[$j] =~ /\bto_/i && $word[$j+1] =~ /_RB|\bjust_|\breally_|\bmost_|\bmore_|_XX0/i && $word[$j+2] =~ /_V/) ||
      ($word[$j] =~ /\bto_/i && $word[$j+1] =~ /_RB|\bjust_|\breally_|\bmost_|\bmore_|_XX0/i && $word[$j+2] =~ /_RB|_XX0/ && $word[$j+3] =~ /_V/) ||

    # Tags split auxiliaries - ELF: merged this variable with split infinitives due to very low counts. ELF: changed all forms of DO to auxiliary DOs only 
      ($word[$j] =~ /_MD|DOAUX|(\b($have))|(\b($be))/i && $word[$j+1] =~ /_RB|\bjust_|\breally_|\bmost_|\bmore_/i && $word[$j+2] =~ /_V/) ||
      ($word[$j] =~ /_MD|DOAUX|(\b($have))|(\b($be))/i && $word[$j+1] =~ /_RB|\bjust_|\breally_|\bmost_|\bmore_|_XX0/i && $word[$j+2] =~ /_RB|_XX0/ && $word[$j+3] =~ /_V/)){
        $word[$j] =~ s/_(\w+)/_$1 SPLIT/;
    }


    #---------------------------------------------------

    # ELF: Attempted to add an alternative stranded "prepositions/particles" - This is currently not in use because it's too inaccurate.
    #if ($word[$j] =~ /\b($particles)_IN|\b($particles)_RP|\b($particles)_RB|to_TO/i && $word[$j+1] =~ /_\W/){
     # $word[$j] =~ s/_(\w+)/_$1 [STPR]/;
    #}

    # Tags stranded prepositions
    # ELF: changed completely since Nini's regex relied on PIN which is no longer a variable in use in the MFTE. 
    if ($word[$j] =~ /\b($preposition)|\bto_TO/i && $word[$j] !~ /_R/ && $word[$j+1] =~ /_\./){
      $word[$j] =~ s/_(\w+)/_$1 STPR/;
    }

    #---------------------------------------------------
    
    # Tags imperatives (in a rather crude way). 
    # ELF: This is a new variable.
    if (($word[$j-1] =~ /_\W|_EMO|_FW|_SYM/ && $word[$j-1] !~ /_:|_'|-RRB-/ && $word[$j] =~ /_VB\b/ && $word[$j] !~ /\bplease_|\bthank_| DOAUX|\b($be)/i && $word[$j+1] !~ /\bI_|\byou_|\bwe_|\bthey_|_NNP/i) || # E.g., "This is a task. Do it." # Added _SYM and _FW because imperatives often start with bullet points which are not always recognised as such. Also added _EMO for texts that use emoji/emoticons instead of punctuation.
     #($word[$j-2] =~ /_\W|_EMO|_FW|_SYM/  && $word[$j-2] !~ /_,/ && $word[$j-1] !~ /_MD/ && $word[$j] =~ /_VB\b/ && $word[$j] !~ /\bplease_|\bthank_| DOAUX|\b($be)/i && $word[$j+1] !~ /\bI_|\byou_|\bwe_|\bthey_|\b_NNP/i) || # Allows for one intervening token between end of previous sentence and imperative verb, e.g., "Just do it!". This line is not recommended for the Spoken BNC2014 and any texts with not particularly good punctuation.
      ($word[$j-2] =~ /_\W|_EMO|_FW|_SYM|_HST/ && $word[$j-2] !~ /_:|_,|_'|-RRB-/ && $word[$j-1] =~ /_RB|_CC|_DMA/ && $word[$j] =~ /_VB\b/ && $word[$j] !~ /\bplease_|\bthank_| DOAUX|\b($be)/i && $word[$j+1] !~ /\bI_|\byou_|\bwe_|\bthey_|_NNP/) || # "Listen carefully. Then fill the gaps."
      ($word[$j-1] =~ /_\W|_EMO|_FW|_SYM|_HST/ && $word[$j-1] !~ /_:|_,|_''|-RRB-/ && $word[$j] =~ /\bpractise_|\bmake_|\bcomplete/i) ||
      ($word[$j] =~ /\bPractise_|\bMake_|\bComplete_|\bMatch_|\bRead_|\bChoose_|\bWrite_|\bListen_|\bDraw_|\bExplain_|\bThink_|\bCheck_|\bDiscuss_/) || # Most frequent imperatives that start sentences in the Textbook English Corpus (TEC) (except "Answer" since it is genuinely also frequently used as a noun)
      ($word[$j-1] =~ /_\W|_EMO|_FW|_SYM|_HST/ && $word[$j-1] !~ /_:|_,|_'/ && $word[$j] =~ /\bdo_/i && $word[$j+1] =~ /_XX0/ && $word[$j+2] =~ /_VB\b/i) || # Do not write. Don't listen.      
      ($word[$j] =~ /\bwork_/i && $word[$j+1] =~ /\bin_/i && $word[$j+2] =~ /\bpairs_/i)) { # Work in pairs because it occurs 700+ times in the Textbook English Corpus (TEC) and "work" is always incorrectly tagged as a noun there.
      $word[$j] =~ s/_\w+/_VIMP/; 
    }

    if (($word[$j-2] =~ /_VIMP/ && $word[$j-1] =~ /\band_|\bor_|,_|&_/i && $word[$j] =~ /_VB\b/ && $word[$j] !~ /\bplease_|\bthank_| DOAUX/i) ||
    	($word[$j-3] =~ /_VIMP/ && $word[$j-1] =~ /\band_|\bor_|,_|&_/i && $word[$j] =~ /_VB\b/ && $word[$j] !~ /\bplease_|\bthank_| DOAUX/i) ||
    	($word[$j-4] =~ /_VIMP/ && $word[$j-1] =~ /\band_|\bor_|,_|&_/i && $word[$j] =~ /_VB\b/ && $word[$j] !~ /\bplease_|\bthank_| DOAUX/i)) {
      $word[$j] =~ s/_\w+/_VIMP/; # This accounts for, e.g., "read (carefully/the text) and listen"
    }
    
    #---------------------------------------------------

    # Tags 'that' adjective complements. 
    # ELF: added the _IN tag onto the "that" to improve accuracy but currently not in use because it still proves to0 errorprone.
    #if ($word[$j-1] =~ /_J/ && $word[$j] =~ /\bthat_IN/i) {
     # $word[$j] =~ s/_\w+/_THAC/;
    #}
    
    # ELF: tags other adjective complements. It's important that WHQU comes afterwards.
    # ELF: also currently not in use because of the high percentage of taggin errors.
    #if ($word[$j-1] =~ /_J/ && $word[$j] =~ /\bwho_|\bwhat_WP|\bwhere_|\bwhy_|\bhow_|\bwhich_/i) {
     # $word[$j] =~ s/_\w+/_WHAC/;
    #}
    
    #---------------------------------------------------
    
	# ELF: Removed Biber's complex and, without manual adjustments, highly unreliable variables WHSUB, WHOBJ, THSUB, THVC, and TOBJ and replaced them with much simpler variables. It should be noted, however, that these variables rely much more on the Stanford Tagger which is far from perfect depending on the type of texts to be tagged. Thorough manual checks are highly recommended before using the counts of these variables!
      
	# That-subordinate clauses other than relatives according to the Stanford Tagger  
    if ($word[$j] =~ /\bthat_IN/i && $word[$j+1] !~ /_\W/) {
      $word[$j] =~ s/_\w+/_THSC/;
      }

    # That-relative clauses according to the Stanford Tagger  
    if ($word[$j] =~ /\bthat_WDT/i && $word[$j+1] !~ /_\W/) {
      $word[$j] =~ s/_\w+/_THRC/;
      }      
      
	# Subordinate clauses with WH-words. 
	# ELF: New variable.
    if ($word[$j] =~ /\b($wp)|\b($who)/i && $word[$j] !~ /_WHQU/) {
      $word[$j] =~ s/_\w+/_WHSC/;
      }
      
    #---------------------------------------------------
  # Shakir: That complement clauses as tagged previously by THSC
    if ($word[$j-1] =~ /\b($th_vb_comm)_V/i && $word[$j] =~ /_THSC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThVCOMM/;
      }

    if ($word[$j-1] =~ /\b($th_vb_att)_V/i && $word[$j] =~ /_THSC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThVATT/;
      }

    if ($word[$j-1] =~ /\b($th_vb_fact)_V/i && $word[$j] =~ /_THSC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThVFCT/;
      }

    if ($word[$j-1] =~ /\b($th_vb_likely)_V/i && $word[$j] =~ /_THSC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThVLIK/;
      }

    if ($word[$j-1] =~ /\b($th_jj_att)_J/i && $word[$j] =~ /_THSC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThJATT/;
      }

    if ($word[$j-1] =~ /\b($th_jj_fact)_J/i && $word[$j] =~ /_THSC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThJFCT/;
      }

    if ($word[$j-1] =~ /\b($th_jj_likely)_J/i && $word[$j] =~ /_THSC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThJLIK/;
      }

    if ($word[$j-1] =~ /\b($th_jj_eval)_J/i && $word[$j] =~ /_THSC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThJEVL/;
      }
    #Shakir: that relative clauses related to attitude
    if ($word[$j-1] =~ /\b($th_nn_nonfact)_N/i && $word[$j] =~ /_THRC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThNNFCT/;
      }

    if ($word[$j-1] =~ /\b($th_nn_att)_N/i && $word[$j] =~ /_THRC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThNATT/;
      }

    if ($word[$j-1] =~ /\b($th_nn_fact)_N/i && $word[$j] =~ /_THRC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThNFCT/;
      }

    if ($word[$j-1] =~ /\b($th_nn_likely)_N/i && $word[$j] =~ /_THRC/) {
      $word[$j] =~ s/_(\w+)/_$1 ThNLIK/;
      }
    #Shakir: wh sub clauses after verb classes
    if ($word[$j-1] =~ /\b($wh_vb_att)_V/i && $word[$j] =~ /_WHSC/) {
      $word[$j] =~ s/_(\w+)/_$1 WhVATT/;
      }

    if ($word[$j-1] =~ /\b($wh_vb_fact)_V/i && $word[$j] =~ /_WHSC/) {
      $word[$j] =~ s/_(\w+)/_$1 WhVFCT/;
      }

    if ($word[$j-1] =~ /\b($wh_vb_likely)_V/i && $word[$j] =~ /_WHSC/) {
      $word[$j] =~ s/_(\w+)/_$1 WhVLIK/;
      }

    if ($word[$j-1] =~ /\b($wh_vb_comm)_V/i && $word[$j] =~ /_WHSC/) {
      $word[$j] =~ s/_(\w+)/_$1 WhVCOM/;
      }
    #---------------------------------------------------
    # Tags hedges 
    # ELF: added "kinda" and "sorta" and corrected the "sort of" and "kind of" lines in Nini's original script which had the word-2 part negated.
    # Also added apparently, conceivably, perhaps, possibly, presumably, probably, roughly and somewhat.
    if (($word[$j] =~ /\bmaybe_|apparently_|conceivably_|perhaps_|\bpossibly_|presumably_|\bprobably_|\broughly_|somewhat_/i) ||
      ($word[$j] =~ /\baround_|\babout_/i && $word[$j+1] =~ /_CD|_QUAN/i)) {
          $word[$j] =~ s/_\w+/_HDG/;
          }
	
	if (($word[$j-1] =~ /\bat_/i && $word[$j] =~ /\babout_/i) ||
      ($word[$j-1] =~ /\bsomething_/i && $word[$j] =~ /\blike_/i) ||
      ($word[$j-2] !~ /_DT|_QUAN|_CD|_J|_PRP|(\b$who)/i && $word[$j-1] =~ /\bsort_/i && $word[$j] =~ /\bof_/i) ||
      ($word[$j-2] !~ /_DT|_QUAN|_CD|_J|_PRP|(\b$who)/i && $word[$j-1] =~ /\bkind_NN/i && $word[$j] =~ /\bof_/i) ||
      ($word[$j-1] !~ /_DT|_QUAN|_CD|_J|_PRP|(\b$who)/i && $word[$j] =~ /\bkinda_|\bsorta_/i)) {
      $word[$j] =~ s/_(\w+)/_$1 HDG/;
    }
    
     if ($word[$j-2] =~ /\bmore_/i && $word[$j-1] =~ /\bor_/i && $word[$j] =~ /\bless_/i) {
      $word[$j] =~ s/_\w+/_QUAN HDG/;
      $word[$j-2] =~ s/\w+/_QUAN/;
     }

    
    #---------------------------------------------------
   
    # Tags politeness markers
    # ELF new variables for: thanks, thank you, ta, please, mind_VB, excuse_V, sorry, apology and apologies.
    if (($word[$j] =~ /\bthank_/i && $word[$j+1] =~ /\byou/i) ||
      ($word[$j] =~ /\bsorry_|\bexcuse_V|\bapology_|\bapologies_|\bplease_|\bcheers_/i) ||
      ($word[$j] =~ /\bthanks_/i && $word[$j+1] !~ /\bto_/i) || # Avoids the confusion with the conjunction "thanks to"
      ($word[$j-1] !~ /\bgot_/i && $word[$j] =~ /\bta_/i) || # Avoids confusion with gotta
      ($word[$j-2] =~ /\bI_|\bwe_/i && $word[$j-1] =~ /\b($be)/i && $word[$j] =~ /\bwonder_V|\bwondering_/i) ||
      ($word[$j-1] =~ /\byou_|_XX0/i && $word[$j] =~ /\bmind_V/i)) {
      $word[$j] =~ s/_(\w+)/_$1 POLITE/;
    }
    
    # Tags HAVE GOT constructions
    # ELF: New variable.
    if ($word[$j] =~ /\bgot/i) {
      if (($word[$j-1] =~ /\b($have)/i) || # have got
        ($word[$j-1] =~ /_RB|_XX0|_EMPH|_DMA/ && $word[$j-2] =~ /\b($have)/i) || # have not got
        ($word[$j-1] =~ /_RB|_XX0|_EMPH|_DMA/ && $word[$j-2] =~ /_RB|_XX0|_EMPH|_DMA/ && $word[$j-3] =~ /\b($have)/i) || # haven't they got
        ($word[$j-1] =~ /_NN|\bi_|\bwe_|\bhe_|\bshe_|\bit_P|\bthey_/ && $word[$j-2] =~ /\b($have)/i) || # has he got?
        ($word[$j-1] =~ /_XX0|_RB|_EMPH|_DMA/ && $word[$j-2] =~ /_NN|\bi_|\bwe_|\bhe_|\bshe_|\bit_P|\bthey_/ && $word[$j-3] =~ /\b($have)/i)) { # hasn't he got?
            $word[$j] =~ s/_\w+/_HGOT/;
      }
      if ($word[$j-1] =~ /\b($have)/i && $word[$j+1] =~ /_VBD|_VBN/) {
      		$word[$j] =~ s/_(\w+)/_PEAS/;
      		$word[$j+1] =~ s/_(\w+)/_PGET/;
      } # Correction for: she has got arrested
      
      if ($word[$j-2] =~ /\b($have)/i && $word[$j-1] =~ /_RB|_XX0|_EMPH|_DMA/i && $word[$j+1] =~ /_VBD|_VBN/) {
            $word[$j] =~ s/_(\w+)/_PEAS/;
      		$word[$j+1] =~ s/_(\w+)/_PGET/;
      } # Correction for: she hasn't got arrested
    }

    #Shakir: preposition after stance nouns
    if ($word[$j-1] =~ /\b($nn_stance_pp)_N/i && $word[$j] =~ /_IN/) {
      $word[$j] =~ s/_(\w+)/_$1 PrepNSTNC/;
    }
    #Shakir: stance nouns without prep
    if ($word[$j] =~ /\b($nn_stance_pp)_N/i && $word[$j+1] !~ /_IN/) {
      $word[$j] =~ s/_(\w+)/_$1 NSTNCother/;
    }    


  }

      #---------------------------------------------------

  
# EVEN MORE COMPLEX TAGS
  
      for ($j=0; $j<@word; $j++) {  

      #---------------------------------------------------
           
    # Tags remaining attribute adjectives (JJAT)

    if (($word[$j-2] =~ /_JJAT/ && $word[$j-1] =~ /\band_/i && $word[$j] =~ /_JJ/) ||
    	($word[$j] =~ /_JJ/ && $word[$j+1] =~ /\band_/i && $word[$j+2] =~ /_JJAT/) ||
    	($word[$j-2] =~ /_JJAT/ && $word[$j-1] =~ /,_,/ && $word[$j] =~ /_JJ/) ||
    	($word[$j] =~ /_JJ/ && $word[$j+1] =~ /,_,/ && $word[$j+2] =~ /_JJAT/) ||
    	($word[$j] =~ /_JJ/ && $word[$j+1] =~ /,_,/ && $word[$j+2] =~ /\band_/ && $word[$j+3] =~ /_JJAT/) ||
    	($word[$j-3] =~ /_JJAT/ && $word[$j-2] =~ /,_,/ && $word[$j-1] =~ /\band_/ && $word[$j] =~ /_JJ/)) {
        $word[$j] =~ s/_\w+/_JJAT/;
    }
    
      #---------------------------------------------------
    
      # Tags perfect aspects # ELF: Changed things around to tag PEAS onto the past participle (and thus replace the VBD/VBN tags) rather than as an add-on to the verb have, as Biber/Nini did. 
      # I tried to avoid as many errors as possible with 's being either BE (= passive) or HAS (= perfect aspect) but this is not perfect. Note that "'s got" and "'s used to" are already tagged separately. 
      # Also note that lemmatisation would not have helped much here because spot checks with Sketch Engine's lemmatiser show that lemmatisers do a terrible job at this, too!
      
    if (($word[$j] =~ /ed_VBD|_VBN/ && $word[$j-1] =~ /\b($have)/i) || # have eaten
        ($word[$j] =~ /ed_VBD|_VBN/ && $word[$j-1] =~ /_RB|_XX0|_EMPH|_PRP|_DMA|_CC/ && $word[$j-2] =~ /\b($have)/i) || # have not eaten
        ($word[$j] =~ /\bbeen_PASS|\bhad_PASS|\bdone_PASS|\b($v_stative)_PASS/i && $word[$j-1] =~ /\bs_VBZ/i) || # This ensures that 's + past participle combinations which are unlikely to be passives are overwritten here as PEAS
        ($word[$j] =~ /\bbeen_PASS|\bhad_PASS|\bdone_PASS|\b($v_stative)_PASS/i && $word[$j-1] =~ /_RB|_XX0|_EMPH|_DMA/ && $word[$j-2] =~ /\bs_VBZ/i) || # This ensures that 's + not/ADV + past participle combinations which are unlikely to be passives are overwritten here as PEAS
        ($word[$j] =~ /ed_VBD|_VBN/ && $word[$j-2] =~ /_RB|_XX0|_EMPH|_CC/ && $word[$j-3] =~ /\b($have)/i) || # haven't really eaten, haven't you noticed?
        ($word[$j] =~ /ed_VBD|_VBN/ && $word[$j-1] =~ /_NN|\bi_|\bwe_|\bhe_|\bshe_|\bit_P|\bthey_/ && $word[$j-2] =~ /\b($have)/i) || # has he eaten?
        ($word[$j-1] =~ /\b($have)/i && $word[$j] =~ /ed_VBD|_VBN/ && $word[$j+1] =~ /_P/) || # has been told or has got arrested
        ($word[$j] =~ /ed_VBD|_VBN/ && $word[$j+1] =~ /_P/ && $word[$j-1] =~ /_XX0|_RB|_EMPH|_DMA|_CC/ && $word[$j-2] =~ /_XX0|_RB|_EMPH/ && $word[$j-3] =~ /\b($have)/i) || #hasn't really been told
        ($word[$j] =~ /ed_VBD|_VBN/ && $word[$j+1] =~ /_PASS/ && $word[$j-1] =~ /_XX0|_RB|_EMPH|_DMA|_CC/ && $word[$j-2] =~ /\b($have)/i) || # hasn't been told
        ($word[$j] =~ /ed_VBD|_VBN/ && $word[$j+1] =~ /_XX0|_EMPH|_DMA|_CC/ && $word[$j-1] =~ /_NN|\bi_|\bwe_|\bhe_|\bshe_|\bit_P|\bthey_/ && $word[$j-2] =~ /\b($have)/i)) { # hasn't he eaten?
     $word[$j] =~ s/_\w+/_PEAS/;
    }
 
 # This corrects some of the 'd wrongly identified as a modal "would" by the Stanford Tagger 
     if ($word[$j-1] =~ /'d_MD/i && $word[$j] =~ /_VBN/) { # He'd eaten
    	$word[$j-1] =~ s/_\w+/_VBD/;
    	$word[$j] =~ s/_\w+/_PEAS/;
    }   
    if ($word[$j-1] =~ /'d_MD/i && $word[$j] =~ /_RB|_EMPH/ && $word[$j+1] =~ /_VBN/) { # She'd never been
    	$word[$j-1] =~ s/_\w+/_VBD/;
    	$word[$j+1] =~ s/_\w+/_PEAS/;
    }

    
 # This corrects some of the 'd wrongly identified as a modal "would" by the Stanford Tagger 
     if ($word[$j] =~ /\bbetter_/ && $word[$j-1] =~ /'d_MD/i) {
    	$word[$j-1] =~ s/_\w+/_VBD/;
    }
    
    if ($word[$j] =~ /_VBN|ed_VBD|en_VBD/ && $word[$j-1] =~ /\band_|\bor_/i && $word[$j-2] =~ /_PASS/)  { # This accounts for the second passive form in phrases such as "they were selected and extracted"
            $word[$j-1] =~ s/_\w+/_CC/; # OR _PHC if this variable is used! (see problems described in tagger performance evaluation)
            $word[$j] =~ s/_\w+/_PASS/;
    }
            
    # ELF: Added a "used to" variable, overriding the PEAS and PASS constructions. Not currently in use due to very low precision (see tagger performance evaluation).
    #if ($word[$j] =~ /\bused_/i && $word[$j+1] =~ /\bto_/) {
     # $word[$j] =~ s/_\w+/_USEDTO/;
    #}
    
    # ELF: tags "able to" constructions. New variable
    if (($word[$j-1] =~ /\b($be)/ && $word[$j] =~ /\bable_JJ|\bunable_JJ/i && $word[$j+1] =~ /\bto_/) ||
     	($word[$j-2] =~ /\b($be)/ && $word[$j] =~ /\bable_JJ|\bunable_JJ/i && $word[$j+1] =~ /\bto_/)) {
      $word[$j] =~ s/_\w+/_ABLE/;
    }
    

  }
      

  #---------------------------------------------------
    
    # ELF: Added a tag for "have got" constructions, overriding the PEAS and PASS constructions.
    
    for ($j=0; $j<@word; $j++) {  
    

  # ELF: tags question tags. New variable
  
  
    if (($word[$j-6] !~ /_WHQU/ && $word[$j-5] !~ /_WHQU/ && $word[$j-4] !~ /_WHQU/ && $word[$j-3] =~ /_MD|\bdid_|\bhad_/i && $word[$j-2] =~ /_XX0/ && $word[$j-1] =~ /_PRP|\bi_|\bwe_|\bhe_|\bshe_|\bit_P|\bthey_/ && $word[$j] =~ /\?_\./) || # couldn't he?
    
    	($word[$j-6] !~ /_WHQU/ && $word[$j-5] !~ /_WHQU/ && $word[$j-4] !~ /_WHQU/ && $word[$j-3] !~ /_WHQU/ && $word[$j-2] =~ /_MD|\bdid_|\bhad_/i && $word[$j-1] =~ /_PRP|\bi_|\bwe_|\bhe_|\bshe_|\bit_P|\bthey_/ && $word[$j] =~ /\?_\./) || # did they?
    	
    	($word[$j-6] !~ /_WHQU/ && $word[$j-5] !~ /_WHQU/ && $word[$j-4] !~ /_WHQU/ && $word[$j-3] =~ /\bis_|\bdoes_|\bwas|\bhas/i && $word[$j-2] =~ /_XX0/ && $word[$j-1] =~ /\bit_|\bshe_|\bhe_/i && $word[$j] =~ /\?_\./)  || # isn't it?
    	
    	($word[$j-6] !~ /_WHQU/ && $word[$j-5] !~ /_WHQU/ && $word[$j-4] !~ /_WHQU/ && $word[$j-3] !~ /_WHQU/ && $word[$j-2] =~ /\bis_|\bdoes_|\bwas|\bhas_/i && $word[$j-1] =~ /\bit_|\bshe_|\bhe_/i && $word[$j] =~ /\?_\./)  || # has she?
    	
    	($word[$j-6] !~ /_WHQU/ && $word[$j-5] !~ /_WHQU/ && $word[$j-4] !~ /_WHQU/ && $word[$j-3] =~ /\bdo|\bwere|\bare|\bhave/i && $word[$j-2] =~ /_XX0/ && $word[$j-1] =~ /\byou_|\bwe_|\bthey_/i && $word[$j] =~ /\?_\./)  || # haven't you?
    	
    	($word[$j-6] !~ /_WHQU/ && $word[$j-5] !~ /_WHQU/ && $word[$j-4] !~ /_WHQU/ && $word[$j-3] !~ /_WHQU/ && $word[$j-2] =~ /\bdo|\bwere|\bare|\bhave/i && $word[$j-1] =~ /\byou_|\bwe_|\bthey_/i && $word[$j] =~ /\?_\./) || # were you?
    	
    	($word[$j-1] =~ /\binnit_|\binit_/ && $word[$j] =~ /\?_\./)) { # innit? init?
    	
         	$word[$j] =~ s/_(\W+)/_$1 QUTAG/;
    }
  }
  
        #---------------------------------------------------
    

    # ELF: added tag for progressive aspects (initially modelled on Nini's algorithm for the perfect aspect). 
    # Note that it's important that this tag has its own loop because it relies on GTO (going to + inf. constructions) having previously been tagged. 
    # Note that this script overrides the _VBG Stanford tagger tag so that the VBG count are now all -ing constructions *except* progressives and GOING-to constructions.
  
    for ($j=0; $j<@word; $j++) {
  
    if ($word[$j] =~ /_VBG/) {
      if (($word[$j-1] =~ /\b($be)/i) || # am eating
        ($word[$j-1] =~ /_RB|_XX0|_EMPH|_CC/ && $word[$j-2] =~ /\b($be)|'m_V/i) || # am not eating
        ($word[$j-1] =~ /_RB|_XX0|_EMPH|_CC/ && $word[$j-2] =~ /_RB|_XX0|_EMPH|_CC/ && $word[$j-3] =~ /\b($be)/i) || # am not really eating
        ($word[$j-1] =~ /_NN|_PRP|\bi_|\bwe_|\bhe_|\bshe_|\bit_P|\bthey_/ && $word[$j-2] =~ /\b($be)/i) || # am I eating
        ($word[$j-1] =~ /_NN|_PRP|\bi_|\bwe_|\bhe_|\bshe_|\bit_P|\bthey_/ && $word[$j-2] =~ /_XX0|_EMPH/ && $word[$j-3] =~ /\b($be)/i) || # aren't I eating?
        ($word[$j-1] =~ /_XX0|_EMPH/ && $word[$j-2] =~ /_NN|_PRP|\bi_|\bwe_|\bhe_|\bshe_|\bit_P|\bthey_/ && $word[$j-3] =~ /\b($be)/i)) { # am I not eating
            $word[$j] =~ s/_\w+/_PROG/;
      }
    }
    
        #---------------------------------------------------
    
    # ELF: Added two new variables for "like" as a preposition (IN) and adjective (JJ) because it most often does not seem to be a preposition (but rather a filler, part of the quotative phrase BE+like, etc.) and should therefore not be added to the preposition count unless it is followed by a noun or adjective.
    # ELF: QLIKE is currently in use due to relatively low precision and recall (see tagger performance evaluation).
      
     #if ($word[$j-1] =~ /\b($be)/ && $word[$j] =~ /\blike_IN|\blike_JJ/i && $word[$j+1] !~ /_NN|_J|_DT|_\.|_,|_IN/) {

      #$word[$j] =~ s/_\w+/_QLIKE/;
    #}
  
     if ($word[$j] =~ /\blike_IN|\blike_JJ|\blike_JJ/i) {

     $word[$j] =~ s/_\w+/_LIKE/;
    }
    
  }
    
    #---------------------------------------------------

    # Tags be as main verb ELF: Ensured that question tags are not being assigned this tag by adding the exceptions of QUTAG occurrences.
    
    for ($j=0; $j<@word; $j++) {  

    if (($word[$j-2] !~ /_EX/ && $word[$j-1] !~ /_EX/ && $word[$j] =~ /\b($be)|\bbeen_/i && $word[$j+1] =~ /_CD|_DT|_PRP|_J|_IN|_QUAN|_EMPH|_CUZ/ && $word[$j+2] !~ /QUTAG|_PROG/ && $word[$j+3] !~ /QUTAG|_PROG/) ||
    
    ($word[$j-2] !~ /_EX/ && $word[$j-1] !~ /_EX/ && $word[$j] =~ /\b($be)|\bbeen_/i && $word[$j+1] =~ /_NN/ && $word[$j+2] =~ /\W+_/ && $word[$j+2] !~ / QUTAG|_PROG/) || # Who is Dinah? Ferrets are ferrets!

    ($word[$j-2] !~ /_EX/ && $word[$j-1] !~ /_EX/ && $word[$j] =~ /\b($be)|\bbeen_/i && $word[$j+1] =~ /_CD|_DT|_PRP|_J|_IN|_QUAN|_RB|_EMPH|_NN/ && $word[$j+2] =~ /_CD|_DT|_PRP|_J|_IN|_QUAN|to_TO|_EMPH/ && $word[$j+2] !~ /QUTAG|_PROG|_PASS/ && $word[$j+3] !~ /QUTAG|_PROG|_PASS/ && $word[$j+4] !~ / QUTAG|_PROG|_PASS/) || # She was so much frightened
    
    ($word[$j-2] !~ /_EX/ && $word[$j-1] !~ /_EX/ && $word[$j] =~ /\b($be)|\bbeen_/i && $word[$j+1] =~ /_RB|_XX0/ && $word[$j+2] =~ /_CD|_DT|_PRP|_J|_IN|_QUAN|_EMPH/ && $word[$j+2] !~ / QUTAG|_PROG|_PASS/ && $word[$j+3] !~ / QUTAG|_PROG|_PASS/)) {
        
        $word[$j] =~ s/_(\w+)/_$1 BEMA/;  
    }
  }
  
  #---------------------------------------------------
  # Tags demonstratives 
  # ELF: New, much simpler variable. Also corrects any leftover "that_IN" and "that_WDT" to DEMO. 
  # These have usually been falsely tagged by the Stanford Tagger, especially they end sentences, e.g.: Who did that?

  for ($j=0; $j<@word; $j++) {

    if ($word[$j] =~ /\bthat_DT|\bthis_DT|\bthese_DT|\bthose_DT|\bthat_IN|\bthat_WDT/i) {
      $word[$j] =~ s/_\w+/_DEMO/;
    }  
  }
  
  
  #---------------------------------------------------
  # Tags subordinator-that deletion 
  # ELF: Added $word+2 in the first pattern to remove "Why would I know that?", 
  # replaced the long MD/do/have/be/V regex that had a lot of redundancies by just MD/V. 
  # In the second pattern, replaced all PRPS by just subject position ones to remove phrases like "He didn't hear me thank God". 
  # Originally also added the pronoun "it" which Nini had presumably forgotten. Then simply used the PRP tag for all personal pronouns.

  for ($j=0; $j<@word; $j++) {

    if (($word[$j] =~ /\b($public|$private|$suasive)/i && $word[$j+1] =~ /_DEMO|_PRP|_N/ && $word[$j+2]=~ /_MD|_V/) ||
    
      ($word[$j] =~ /\b($public|$private|$suasive)/i && $word[$j+1] =~ /_PRP|_N/ && $word[$j+2] =~ /_MD|_V/) ||
      
      ($word[$j] =~ /\b($public|$private|$suasive)/i && $word[$j+1] =~ /_J|_RB|_DT|_QUAN|_CD|_PRP/ && $word[$j+2] =~ /_N/ && $word[$j+3] =~ /_MD|_V/) ||
      
      ($word[$j] =~ /\b($public|$private|$suasive)/i && $word[$j+1] =~ /_J|_RB|_DT|_QUAN|_CD|_PRP/ && $word[$j+2] =~ /_J/ && $word[$j+3] =~ /_N/ && $word[$j+4] =~ /_MD|_V/)) {
      
      $word[$j] =~ s/_(\w+)/_$1 THATD/;
    }
  }

  
        #---------------------------------------------------
   
  
    # Tags pronoun it ELF: excluded IT (all caps) from the list since it usually refers to information technology

  
  for ($j=0; $j<@word; $j++) {  
  
    if (($word[$j] =~ /\bits_|\bitself_/i) ||
    	($word[$j] =~ /\bit_|\bIt_/)) {
      		$word[$j] =~ s/_\w+/_PIT/;
      }
    }
    
  #---------------------------------------------------
    
    # Tags first person pronouns ELF: Added exclusion of occurrences of US (all caps) which usually refer to the United States.
    # ELF: Added 's_PRP to account for abbreviated "us" in "let's" Also added: mine, ours.
    # ELF: Subdivided Biber's FPP1 into singular (interactant = speaker) and plural (interactant = speaker and others).
    
  for ($j=0; $j<@word; $j++) {  
    
    if ($word[$j] =~ /\bI_P|\bme_|\bmy_|\bmyself_|\bmine_|\bi_SYM|\bi_FW/i) {
      		$word[$j] =~ s/_\w+/_FPP1S/;
      }
      
    if (($word[$j] =~ /\bwe_|\bour_|\bourselves_|\bours_|'s_PRP/i) ||
     	($word[$j] =~ /\bus_P|\bUs_P/)) {
      		$word[$j] =~ s/_\w+/_FPP1P/;
      }
      
    if ($word[$j] =~ /\blet_/i && $word[$j+1] =~ /'s_|\bus_/i) {
    		$word[$j] =~ s/_\w+/_VIMP/;
    		$word[$j+1] =~ s/_\w+/_FPP1P/;
      }
    
    if ($word[$j] =~ /\blet_/i && $word[$j+1] =~ /\bme_/i) {
    		$word[$j] =~ s/_\w+/_VIMP/;
    		$word[$j+1] =~ s/_\w+/_FPP1S/;
      }
  
      
    }
    
  #---------------------------------------------------
    
  for ($j=0; $j<@word; $j++) {  
    
       # Tags concessive conjunctions 
       # Nini had already added "THO" to Biber's list.
       # ELF added: despite, albeit, yet, except that, in spite of, granted that, granted + punctuation, no matter + WH-words, regardless of + WH-word. 
       # Also added: nevertheless, nonetheless and notwithstanding and whereas, which Biber had as "other adverbial subordinators" (OSUB, a category ELF removed).
       
    if (($word[$j] =~ /\balthough_|\btho_|\bdespite|\balbeit_|nevertheless_|nonetheless_|notwithstanding_|\bwhereas_/i) ||
		($word[$j] =~ /\bexcept_/i && $word[$j+1] =~ /\bthat_/i) ||    	
		($word[$j] =~ /\bgranted_/i && $word[$j+1] =~ /\bthat_|_,/i) ||		
		($word[$j] =~ /\bregardless_|\birregardless_/i && $word[$j+1] =~ /\bof_/i) ||
    	($word[$j] =~ /\byet_|\bstill_/i && $word[$j+1] =~ /_,/i) ||
    	($word[$j-1] !~ /\bas_/i && $word[$j] =~ /\bthough_/i) ||
    	($word[$j] =~ /\byet_|\bgranted_|\bstill_/i && $word[$j-1] =~ /_\W/i)) {
     	 	$word[$j] =~ s/_\w+/_CONC/;
    	}

    if (($word[$j-1] =~ /\bno_/i && $word[$j] =~ /\bmatter_/i && $word[$j+1] =~ /\b$whw/i) ||
    	($word[$j-1] =~ /\bin_/i && $word[$j] =~ /\bspite_/ && $word[$j+1] =~ /\bof_/)) {
     	 	$word[$j] =~ s/_(\w+)/_$1 CONC/;
   	 	} 

    #---------------------------------------------------

    # Tags place adverbials 
    # ELF: added all the words from "downwind" onwards and excluded "there" tagged as an existential "there" as in "there are probably lots of bugs in this script". Also restricted above, around, away, behind, below, beside, inside and outside to adverb forms only.
    if ($word[$j] =~ /\baboard_|\babove_RB|\babroad_|\bacross_RB|\bahead_|\banywhere_|\balongside_|\baround_RB|\bashore_|\bastern_|\baway_RB|\bbackwards?|\bbehind_RB|\bbelow_RB|\bbeneath_|\bbeside_RB|\bdownhill_|\bdownstairs_|\bdownstream_|\bdownwards_|\beast_|\bhereabouts_|\bindoors_|\binland_|\binshore_|\binside_RB|\blocally_|\bnear_|\bnearby_|\bnorth_|\bnowhere_|\boutdoors_|\boutside_RB|\boverboard_|\boverland_|\boverseas_|\bsouth_|\bunderfoot_|\bunderground_|\bunderneath_|\buphill_|\bupstairs_|\bupstream_|\bupwards?|\bwest_|\bdownwind|\beastwards?|\bwestwards?|\bnorthwards?|\bsouthwards?|\belsewhere|\beverywhere|\bhere_|\boffshore|\bsomewhere|\bthereabouts?|\bfar_RB|\bthere_RB|\bonline_|\boffline_N/i 
    && $word[$j] !~ /_NNP/) {
        $word[$j] =~ s/_\w+/_PLACE/;
    }
    
    if ($word[$j] =~ /\bthere_P/i && $word[$j+1] =~ /_MD/) { # Correction of there + modals, e.g. there might be that option which are frequently not recognised as instances of there_EX by the Stanford Tagger
        $word[$j] =~ s/_\w+/_EX/;
    }

    #---------------------------------------------------

    # Tags time adverbials 
    # ELF: Added already, so far, thus far, yet (if not already tagged as CONC above) and ago. Restricted after and before to adverb forms only.
    if (($word[$j] =~ /\bago_|\bafter_RB|\bafterwards_|\bagain_|\balready_|\bbefore_RB|\bbeforehand_|\bbriefly_|\bcurrently_|\bearlier_|\bearly_RB|\beventually_|\bformerly_|\bimmediately_|\binitially_|\binstantly_|\bforeever_|\blate_RB|\blately_|\blater_|\bmomentarily_|\bnow_|\bnowadays_|\bonce_|\boriginally_|\bpresently_|\bpreviously_|\brecently_|\bshortly_|\bsimultaneously_|\bsooner_|\bsubsequently_|\bsuddenly|\btoday_|\bto-day_|\btomorrow_|\bto-morrow_|\btonight_|\bto-night_|\byesterday_|\byet_RB|\bam_RB|\bpm_RB/i) ||
    	($word[$j] =~ /\bsoon_/i && $word[$j+1] !~ /\bas_/i) ||
    	($word[$j] =~ /\bprior_/i && $word[$j+1] =~ /\bto_/i) ||
    	($word[$j-1] =~ /\bso_|\bthus_/i && $word[$j] =~ /\bfar_/i && $word[$j+1] !~ /_J|_RB/i)) {
      $word[$j] =~ s/_\w+/_TIME/;
    	}
    	
	}
   	 
    #---------------------------------------------------
    
    # Tags pro-verb do ELF: This is an entirely new way to operationalise the variable. Instead of identifying the pro-verb DO, I actually identify DO as an auxiliary early (DOAUX) and here I take other forms of DO as a verb as pro-verbs. This is much more reliable than Nini's method which, among other problems, tagged all question tags as the pro-verb DO. 
    # ELF: Following discussing with PU on the true definition of pro-verbs, removed this variable altogether and adding all non-auxiliary DOs to the activity verb list.
    
  for ($j=0; $j<@word; $j++) {  
    
    if ($word[$j] =~ /\b($do)/i && $word[$j] !~ / DOAUX/) {
      $word[$j] =~ s/_(\w+)/_$1 ACT/;
      }
      
    # Adds "NEED to" and "HAVE to" to the list of necessity (semi-)modals  
    if ($word[$j] =~ /\bneed_V|\bneeds_V|\bneeded_V|\bhave_V|\bhas_V|\bhad_V|\bhaving_V/i && $word[$j+1] =~ /\bto_TO/) {
      $word[$j] =~ s/_(\w+)/_MDNE/;
      }
      
    }
  
    
  #--------------------------------------------------- 
  
  # BASIC TAGS THAT HAVE TO BE TAGGED AT THE END TO AVOID CLASHES WITH MORE COMPLEX REGEX ABOVE
  foreach $x (@word) {

    # Tags amplifiers 
    # ELF: Added "more" as an adverb (note that "more" as an adjective is tagged as a quantifier further up)
    if ($x =~ /\babsolutely_|\baltogether_|\bcompletely_|\benormously_|\bentirely_|\bextremely_|\bfully_|\bgreatly_|\bhighly_|\bintensely_|\bmore_RB|\bperfectly_|\bstrongly_|\bthoroughly_|\btotally_|\butterly_|\bvery_/i) {
      $x =~ s/_\w+/_AMP/;
    }

    # Tags downtoners
    # ELF: Added "less" as an adverb (note that "less" as an adjective is tagged as a quantifier further up)
    # ELF: Removed "only" because it fulfils too many different functions.
    if ($x =~ /\balmost_|\bbarely_|\bhardly_|\bless_JJ|\bmerely_|\bmildly_|\bnearly_|\bpartially_|\bpartly_|\bpractically_|\bscarcely_|\bslightly_|\bsomewhat_/i) {
      $x =~ s/_\w+/_DWNT/;
    }
   
    # Corrects EMO tags
    # ELF: Correction of emoticon issues to do with the Stanford tags for brackets including hyphens
    if ($x =~ /_EMO(.)*-/i) {
      $x =~ s/_EMO(.)*-/_EMO/;
    }
    
    
    # Tags quantifier pronouns 
    # ELF: Added any, removed nowhere (which is now place). "no one" is also tagged for at an earlier stage to avoid collisions with the XX0 variable.
    if ($x =~ /\banybody_|\banyone_|\banything_|\beverybody_|\beveryone_|\beverything_|\bnobody_|\bnone_|\bnothing_|\bsomebody_|\bsomeone_|\bsomething_|\bsomewhere|\bnoone_|\bno-one_/i) {      
    $x =~ s/_\w+/_QUPR/;
    }

    # Tags nominalisations à la Biber (1988)
    # ELF: Not in use in this version of the MFTE due to frequent words skewing results, e.g.: activity, document, element...
    #if ($x =~ /tions?_NN|ments?_NN|ness_NN|nesses_NN|ity_NN|ities_NN/i) {
     # $x =~ s/_\w+/_NOMZ/;
    #}

    # Tags gerunds 
    # ELF: Not currently in use because of doubts about the usefulness of this category (cf. Herbst 2016 in Applied Construction Grammar) + high rate of false positives with Biber's/Nini's operationalisation of the variable.
    #if (($x =~ /ing_NN/i && $x =~ /\w{10,}/) ||
     # ($x =~ /ings_NN/i && $x =~ /\w{11,}/)) {
      #$x =~ s/_\w+/_GER/;
    #}
    
    # ELF added: pools together all proper nouns (singular and plural). Not currently in use since no distinction is made between common and proper nouns.
    #if ($x =~ /_NNPS/) {
     # $x =~ s/_\w+/_NNP/;
    #}
        
    # Tags predicative adjectives (JJPR) by joining all kinds of JJ (but not JJAT, see earlier loop)
    if ($x =~ /_JJS|_JJR|_JJ\b/) {
      $x =~ s/_\w+/_JJPR/;
    }

    # Tags total adverbs by joining all kinds of RB (but not those already tagged as HDG, FREQ, AMP, DWNTN, EMPH, ELAB, EXTD, TIME, PLACE...).
    if ($x =~ /_RBS|_RBR|_WRB/) {
      $x =~ s/_\w+/_RB/;
    }

    # Tags present tenses
    if ($x =~ /_VBP|_VBZ/) {
      $x =~ s/_\w+/_VPRT/;
    }

    # Tags second person pronouns - ADDED "THOU", "THY", "THEE", "THYSELF" ELF: added nominal possessive pronoun (yours), added ur, ye and y' (for y'all).
    if ($x =~ /\byou_|\byour_|\byourself_|\byourselves_|\bthy_|\bthee_|\bthyself_|\bthou_|\byours_|\bur_|\bye_PRP|\by'_|\bthine_|\bya_PRP/i) {
      $x =~ s/_\w+/_SPP2/;
    }

    # Tags third person pronouns 
    # ELF: added themself in singular (cf. https://www.lexico.com/grammar/themselves-or-themself), added nominal possessive pronoun forms (hers, theirs), also added em_PRP for 'em.
    # ELF: Subdivided Biber's category into non-interactant plural and non-plural.
     if ($x =~ /\bthey_|\bthem_|\btheir_|\bthemselves_|\btheirs_|em_PRP/i) {
      $x =~ s/_\w+/_TPP3P/;
    }
    # Note that this variable cannot account for singular they except for the reflective form.
     if ($x =~ /\bhe_|\bshe_|\bher_|\bhers_|\bhim_|\bhis_|\bhimself_|\bherself_|\bthemself_/i) {
      $x =~ s/_\w+/_TPP3S/;
    }
    
    # Tags "can" modals 
    # ELF: added _MD onto all of these. And ca_MD which was missing for can't.
    if ($x =~ /\bcan_MD|\bca_MD/i) {
      $x =~ s/_\w+/_MDCA/;
    }
    
    # Tags "could" modals
    if ($x =~ /\bcould_MD/i) {
      $x =~ s/_\w+/_MDCO/;
    }

    # Tags necessity modals
    # ELF: added _MD onto all of these to increase precision.
    if ($x =~ /\bought_MD|\bshould_MD|\bmust_MD|\bneed_MD/i) {
      $x =~ s/_\w+/_MDNE/;
    }

    # Tags "may/might" modals
    # ELF: added _MD onto all of these to increase precision.
    if ($x =~ /\bmay_MD|\bmight_MD/i) {
      $x =~ s/_\w+/_MDMM/;
    }
    
    # Tags will/shall modals. 
    # ELF: New variable replacing Biber's PRMD.
    if ($x =~ /\bwill_MD|'ll_MD|\bshall_|\bsha_|\bwo_MD/i) {
      $x =~ s/_\w+/_MDWS/;
    }

    # Tags would as a modal. 
    # ELF: New variable replacing PRMD.
    if ($x =~ /\bwould_|'d_MD/i) {
      $x =~ s/_\w+/_MDWO/;
    }
    
    # ELF: tags activity verbs. 
    # Note that adding _P is important to capture verbs tagged as PEAS, PROG or_PASS.
    if ($x =~ /\b($vb_act)_V|\b($vb_act)_P/i) {
      $x =~ s/_(\w+)/_$1 ACT/;
    }
    
    # ELF: tags communication verbs. 
    # Note that adding _P is important to capture verbs tagged as PEAS, PROG or PASS.
    if ($x =~ /\b($vb_comm)_V|\b($vb_comm)_P/i) {
      $x =~ s/_(\w+)/_$1 COMM/;
    }
    
    # ELF: tags mental verbs (including the "no" in "I dunno" and "wa" in wanna). 
    # Note that adding _P is important to capture verbs tagged as PEAS, PROG or PASS.
    if ($x =~ /\b($vb_mental)_V|\b($vb_mental)_P|\bno_VB/i) {
      $x =~ s/_(\w+)/_$1 MENTAL/;
    }
    
    # ELF: tags causative verbs. 
    # Note that adding _P is important to capture verbs tagged as PEAS, PROG or PASS.
    if ($x =~ /\b($vb_cause)_V|\b($vb_cause)_P/i) {
      $x =~ s/_(\w+)/_$1 CAUSE/;
    }
    
    # ELF: tags occur verbs. 
    # Note that adding _P is important to capture verbs tagged as PEAS, PROG or PASS.
    if ($x =~ /\b($vb_occur)_V|\b($vb_occur)_P/i) {
      $x =~ s/_(\w+)/_$1 OCCUR/;
    }
    
    # ELF: tags existential verbs. 
    # Note that adding _P is important to capture verbs tagged as PEAS, PROG or PASS.
    if ($x =~ /\b($vb_exist)_V|\b($vb_exist)_P/i) {
      $x =~ s/_(\w+)/_$1 EXIST/;
    }
    
    # ELF: tags aspectual verbs. 
    # Note that adding _P is important to capture verbs tagged as PEAS, PROG or PASS.
    if ($x =~ /\b($vb_aspect)_V|\b($vb_aspect)_P/i) {
      $x =~ s/_(\w+)/_$1 ASPECT/;
    }
  #--------------------------------------------------------------  
    #Shakir: noun and adverb semantic categories from Biber 2006, if there is no additional tag added previously (hence the space check)
    if ($x =~ /\b($nn_human)_N/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 NNHUMAN/;
    }
    
    if ($x =~ /\b($nn_cog)_N/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 NNCOG/;
    }

    if ($x =~ /\b($nn_concrete)_N/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 NNCONC/;
    }

    if ($x =~ /\b($nn_place)_N/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 NNPLACE/;
    }
    
    if ($x =~ /\b($nn_quant)_N/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 NNQUANT/;
    }

    if ($x =~ /\b($nn_group)_N/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 NNGRP/;
    }

    if ($x =~ /\b($nn_technical)_N/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 NNTECH/;
    }
    if ($x =~ /\b($nn_abstract_process)_N/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 NNABSPROC/;
    }
    if ($x =~ /\b($jj_size)_J/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 JJSIZE/;
    }
  
    if ($x =~ /\b($jj_time)_J/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 JJTIME/;
    }

    if ($x =~ /\b($jj_color)_J/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 JJCOLR/;
    }

    if ($x =~ /\b($jj_eval)_J/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 JJEVAL/;
    }

    if ($x =~ /\b($jj_relation)_J/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 JJREL/;
    }

    if ($x =~ /\b($jj_topic)_J/i && $x !~ / /) {
      $x =~ s/_(\w+)/_$1 JJTOPIC/;
    }
    #----------------------------------------
    # Tags verbal contractions
    if ($x =~ /'\w+_V|\bn't_XX0|'ll_|'d_/i) {
      $x =~ s/_(\w+)/_$1 CONT/;
    }
    
    # tags the remaining interjections and filled pauses. 
    # ELF: added variable
    # Note: it is important to keep this variable towards the end because some UH tags need to first be overridden by other variables such as politeness (please) and pragmatic markers (yes). 
    if ($x =~ /_UH/) {
      $x =~ s/_(\w+)/_FPUH/;
    }
      
    # ELF: added variable: tags adverbs of frequency (list from COBUILD p. 270).
    if ($x =~ /\busually_|\balways_|\bmainly_|\boften_|\bgenerally|\bnormally|\btraditionally|\bagain_|\bconstantly|\bcontinually|\bfrequently|\bever_|\bnever_|\binfrequently|\bintermittently|\boccasionally|\boftens_|\bperiodically|\brarely_|\bregularly|\brepeatedly|\bseldom|\bsometimes|\bsporadically/i) {
      $x =~ s/_(\w+)/_FREQ/;
    }
    
    # ELF: remove the TO category which was needed for the identification of other features put overlaps with VB
    if ($x =~ /_TO/) {
      $x =~ s/_(\w+)/_IN/;
    }    
  }
  
    #---------------------------------------------------

	# Tags noun compounds 
	# ELF: New variable. Only works to reasonable degree of accuracy with "well-punctuated" (written) language, though.
	# Allows for the first noun to be a proper noun but not the second thus allowing for "Monday afternoon" and "Hollywood stars" but not "Barack Obama" and "L.A.". Also restricts to nouns with a minimum of two letters to avoid OCR errors (dots and images identified as individual letters and which are usually tagged as nouns) producing lots of NCOMP's.
	
  for ($j=0; $j<@word; $j++) {
	
	if ($word[$j] =~ /\b.{2,}_NN/ && $word[$j+1] =~ /\b(.{2,}_NN|.{2,}_NNS)\b/ && $word[$j] !~ /\NCOMP/) {
		$word[$j+1] =~ s/_(\w+)/_$1 NCOMP/;
    }
      
    # Tags total nouns by joining plurals together with singulars including of proper nouns.
  if ($word[$j] =~ /_NN|_NNS|_NNP|_NNPS/) {
      $word[$j] =~ s/_\w+/_NN/;
    }

    #---------------------------------------------------

	#Shakir: Nini's (2014) implementation for nominalisations with a length check of more than 5 characters, and no space means no other extra tag added
	if ($word[$j] =~ /tions?_NN|ments?_NN|ness_NN|nesses_NN|ity_NN|ities_NN/i && $word[$j] =~ /[a-z]{5,}/i && $word[$j] !~ / /) {
				$word[$j] =~ s/_(\w+)/_$1 NOMZ/;
			}
  #Shakir: Semantic classes of adverbs
  if (($word[$j] =~ /\b($advl_att)_R/i && $word[$j] !~ / /) ||
  ($word[$j] =~ /\b(even)_R/i && $word[$j+1] =~ /\b(worse)_/i && $word[$j] !~ / /)) {
    $word[$j] =~ s/_(\w+)/_$1 RATT/;
  }

  if ($word[$j] =~ /\b($advl_nonfact)_R/i && $word[$j] !~ / /) {
    $word[$j] =~ s/_(\w+)/_$1 RNONFACT/;
  }

  if (($word[$j] =~ /\b($advl_fact)_R/i && $word[$j] !~ / /) ||
  ($word[$j-1] =~ /\b(of)_/i && $word[$j] =~ /\b(course)_/i && $word[$j] !~ / /) ||
  ($word[$j-1] =~ /\b(in)_/i && $word[$j] =~ /\b(fact)_/i && $word[$j] !~ / /) ||
  ($word[$j-1] =~ /\b(without|no)_/i && $word[$j] =~ /\b(doubt)_/i && $word[$j] !~ / /)) {
    $word[$j] =~ s/_(\w+)/_$1 RFACT/;
  }

  if (($word[$j] =~ /\b($advl_likely)_R/i && $word[$j] !~ / /) ||
  ($word[$j-1] =~ /\b(in)_/i && $word[$j] =~ /\b(most)_/i && $word[$j+1] =~ /\b(cases)_/i)) {
    $word[$j] =~ s/_(\w+)/_$1 RLIKELY/;
  }
    #Shakir: Add new variable to avoid overlap in the above two sub classes and JJAT/JJPR
  if ($word[$j] =~ /_JJAT$/) {
    $word[$j] =~ s/_(\w+)/_$1 JJATother/;
    }

  if ($word[$j] =~ /_JJPR$/) {
    $word[$j] =~ s/_(\w+)/_$1 JJPRother/;
    }

    #Shakir: Add new variable to avoid overlap in THSC and all above TH_J and TH_V clauses
    if ($word[$j] =~ /_THSC$/) {
      $word[$j] =~ s/_(\w+)/_$1 THSCother/;
      }    

    #Shakir: Add new variable to avoid overlap in THRC and all above TH_N clauses
    if ($word[$j] =~ /_THRC$/) {
      $word[$j] =~ s/_(\w+)/_$1 THRCother/;
      }    

    #Shakir: Add new variable to avoid overlap in WHSC and WH_V clauses
    if ($word[$j] =~ /_WHSC$/) {
      $word[$j] =~ s/_(\w+)/_$1 WHSCother/;
      }

    #Shakir: Add new variable to avoid overlap in NN and N semantic/other sub classes
    if ($word[$j] =~ /_NN$/) {
      $word[$j] =~ s/_(\w+)/_$1 NNother/;
      }

    #Shakir: Add new variable to avoid overlap in RB and R semantic sub classes
    if ($word[$j] =~ /_RB$/) {
      $word[$j] =~ s/_(\w+)/_$1 RBother/;
      }

    #Shakir: Add new variable to avoid overlap in IN and PrepNNStance
    if ($word[$j] =~ /_IN$/) {
      $word[$j] =~ s/_(\w+)/_$1 INother/;
      }

    #Shakir: verbs in contexts other than _WHSC, _THSC or to_ . Additionally not assigned to another tag.
    if ($word[$j] =~ /\b($comm_vb_other)_V/i && $word[$j+1] !~ /_WHSC|_THSC|to_/ && $word[$j] !~ / /) {
      $word[$j] =~ s/_(\w+)/_$1 VCOMMother/;
      }
    
    if ($word[$j] =~ /\b($att_vb_other)_V/i && $word[$j+1] !~ /_WHSC|_THSC|to_/ && $word[$j] !~ / /) {
      $word[$j] =~ s/_(\w+)/_$1 VATTother/;
      }    

    if ($word[$j] =~ /\b($fact_vb_other)_V/i && $word[$j+1] !~ /_WHSC|_THSC|to_/ && $word[$j] !~ / /) {
      $word[$j] =~ s/_(\w+)/_$1 VFCTother/;
      }
    
    if ($word[$j] =~ /\b($likely_vb_other)_V/i && $word[$j+1] !~ /_WHSC|_THSC|to_/ && $word[$j] !~ / /) {
      $word[$j] =~ s/_(\w+)/_$1 VLIKother/;
      }

    #Shakir: sums of that clauses for vb, jj, nn and all to be used if original are too low freq
    if ($word[$j] =~ / (ThVCOMM|ThVATT|ThVFCT|ThVLIK)/) {
      $word[$j] =~ s/_(\w+)/_$1 ThVSTNCAll/;
      }
    #Shakir: sums of that clauses for vb other that comm verbs
    if ($word[$j] =~ / (ThVATT|ThVFCT|ThVLIK)/) {
      $word[$j] =~ s/_(\w+)/_$1 ThVSTNCother/;
      }
    if ($word[$j] =~ / (ThJATT|ThJFCT|ThJLIK|ThJEVL)/) {
      $word[$j] =~ s/_(\w+)/_$1 ThJSTNCAll/;
      }

    if ($word[$j] =~ / (ThNNFCT|ThNATT|ThNFCT|ThNLIK)/) {
      $word[$j] =~ s/_(\w+)/_$1 ThNSTNCAll/;
      }  

    if ($word[$j] =~ / (ThVCOMM|ThVATT|ThVFCT|ThVLIK|ThJATT|ThJFCT|ThJLIK|ThJEVL|ThNNFCT|ThNATT|ThNFCT|ThNLIK)/) {
      $word[$j] =~ s/_(\w+)/_$1 ThSTNCAll/;
      }
    #Shakir: wh vb stance all
    if ($word[$j] =~ / (WhVATT|WhVFCT|WhVLIK|WhVCOM)/) {
      $word[$j] =~ s/_(\w+)/_$1 WhVSTNCAll/;
      }
    #Shakir: adverb stance all
    if ($word[$j] =~ / (RATT|RNONFACT|RFACT|RLIKELY)/) {
      $word[$j] =~ s/_(\w+)/_$1 RSTNCAll/;
      }
    #Shakir: adverb stance other than RFACT
    if ($word[$j] =~ / (RATT|RNONFACT|RLIKELY)/) {
      $word[$j] =~ s/_(\w+)/_$1 RSTNCother/;
      }    

    #Shakir: all possibility modals Biber 1988
    if ($word[$j] =~ /(MDCA|MDCO|MDMM)/) {
      $word[$j] =~ s/_(\w+)/_$1 MDPOSSCAll/;
      }
    
    #Shakir: all prediction modals Biber 1988 + Going to
    if ($word[$j] =~ /(MDWS|MDWO|GTO)\b/) {
      $word[$j] =~ s/_(\w+)/_$1 MDPREDAll/;
      }
    
    #Shakir: all passive voice as Le Foll counts PASS and PGET
    if ($word[$j] =~ /(PASS|PGET)\b/) {
      $word[$j] =~ s/_(\w+)/_$1 PASSAll/;
      }
    
    #Shakir: all stance noun complements (To + Th)
    if ($word[$j] =~ /(ToNSTNC|ThNSTNCAll)\b/) {
      $word[$j] =~ s/_(\w+)/_$1 ToThNSTNCAll/;
      }
    
    #Shakir: consolidate description adjectives
    if ($word[$j] =~ /(JJSIZE|JJCOLR)\b/) {
      $word[$j] =~ s/_(\w+)/_$1 JJDESCAll/;
      }
    #Shakir: consolidate stance adjectives
    if ($word[$j] =~ /(JJEPSTother|JJATDother)\b/) {
      $word[$j] =~ s/_(\w+)/_$1 JJEpstAtdOther/;
      }
    #Shakir: All 1st person pronouns to 1 tag
    if ($word[$j] =~ /_(FPP1P|FPP1S)\b/) {
      $word[$j] =~ s/_(\w+)/_$1 FPPAll/;
      }
    #Shakir: All stance verbs in other contexts
    if ($word[$j] =~ / (VCOMMother|VATTother|VFCTother|VLIKother)\b/) {
      $word[$j] =~ s/_(\w+)/_$1 VSTNCOtherAll/;
      }
    #Shakir: Non past tense imperatives, present tense, future markers 
    if ($word[$j] =~ /(VPRT|VIMP|MDPREDAll|MDNE|MDPOSSCAll|VB)\b/) {
      $word[$j] =~ s/_(\w+)/_$1 VNONPAST/;
      }
    #Shakir: fixed it tagged as PRP 
    if ($word[$j] =~ /(It|its?|itself)_PRP\b/) {
      $word[$j] =~ s/_(\w+)/_PIT/;
      }
  }
  return @word;
}


############################################################
## Obtain feature counts in table formats.

##   do_counts($prefix, $tagged_dir, $tokens_for_ttr);
sub do_counts {
  my ($prefix, $tagged_dir, $tokens_for_ttr) = @_;

  opendir(DIR, $tagged_dir) or die "Can't read directory $tagged_dir/: $!";
  my @filenames = grep {-f "$tagged_dir/$_"} readdir(DIR);
  close(DIR);
  my $Stat_dir = "$tagged_dir/Statistics";
  unless (-d $Stat_dir) {
  mkdir $Stat_dir or die "Can't create output directory $Stat_dir/: $!";
  }
  die "Error: $Stat_dirDir exists but isn't a directory\n" unless -d $Stat_dir;
  
  my $n_files = @filenames;
  
  my @tokens = (); # tokens counts
  my %counts = (); # feature counts
  my %ttr_h = ();  # type/token ratio (TTR) 
  my %lex_density = (); # for lexical density
  
  
  ## read each file and
  foreach my $i (0 .. $n_files - 1) {
    my $textname = $filenames[$i];
    print STDERR "Counting tags file $tagged_dir/$filenames[$i]\n";
    {
      local $/ = undef ;
      open(FH, "$tagged_dir/$filenames[$i]") or die "Can't read tagged file $tagged_dir/$filenames[$i]: $!";
      $text = <FH>;
      close(FH);
    }

    $text =~ s/\n/ /g;  #converts end of line in space
    #@word = split (/\s+/, $text);
    # The following line was contributed by Peter Uhrig to account for non-breaking spaces within tokens (UTF-8 C2 A0). It has not yet been sufficiently tested to be yet in use.
    @word = split (/ +/, $text);
    @types = (); # SE: actually, these are the tokens (without tags)
    @functionwords = ();


    foreach $x (@word) {

# ELF: Corrected an error in the MAT which did NOT ignore punctuation in token count (although comments said it did). Also decided to remove possessive s's, symbols, filled pauses and interjections (FPUH) from this count.
      $tokens[$i]++;
      if ($x =~ /(_\s)|(\[\w+\])|(.+_\W+)|(-RRB-_-RRB-)|(-LRB-_-LRB-)|.+_SYM|_POS|_FPUH/) {  
        $tokens[$i]--;
      }
# EFL: Counting function words for lexical density
	  if ($x =~ /\b($function_words)_/i) {
	  	$functionwords[$i]++;
	  }
	  
# EFL: Counting total nouns for per 100 noun normalisation
	  if ($x =~ /_NN/) {
	  	$NTotal[$i]++;
	  }
	  
# EFL: Approximate counting of total finite verbs for the per 100 finite verb normalisation
	  if ($x =~ /_VPRT|_VBD|_VIMP|_MDCA|_MDCO|_MDMM|_MDNE|_MDWO|_MDWS/) {
	  	$VBTotal[$i]++;
	  }

# ELF: I've decided to exclude all of these for the word length variable (i.e., possessive s's, symbols, punctuation, brackets, filled pauses and interjections (FPUH)):
      if ($x !~ /(_\s)|(\[\w+\])|(.+_\W+)|(-RRB-_-RRB-)|(-LRB-_-LRB-)|.+_SYM|_POS|_FPUH/) { 
      
        my($wordl, $tag) = split (/_(?!_)/, $x, 2); #divides the word in tag and word
        $wordlength = length($wordl);
        $totalchar{$textname} = $totalchar{$textname} + $wordlength;
        push @types, $wordl; # prepares array for TTR
      }

# ELF: List of tags for which no counts will be returned:
	# Note: if interested in counts of punctuation marks, "|_\W+" should be deleted in this line:
      if ($x !~ /_LS|_\W+|_WP\b|_FW|_SYM|_MD\b|_VB\b/) {  
        $x =~ s/^.*_//; # removes the word and leaves just the tag
        #print "$x\n";
        $counts{$x}{$textname}++; # creates and then fills a hash: POStag => number of occurrences for the file considered
      }

    }
    
    $average_wl{$textname} = $totalchar{$textname} / $tokens[$i]; # average word length
    
    $lex_density{$textname} = ($tokens[$i] - $functionwords[$i]) / $tokens[$i]; # ELF: lexical density
    
    #$func{$textname} = -$functionwords[$i]; # ELF: For debugging
        
    for ($j=0; $j<$tokens_for_ttr; $j++) { # Calculates TTR
      last if $j >= @types; # Stops if text is shorter than specified TTR size
      $ttr_h{$textname}++;
      if (exists ($ttr{lc($types[$j])}{$textname})) {
        $ttr_h{$textname}--;
      } else {
        $ttr{lc($types[$j])}{$textname}++;
      }
    }
    $ttr_h{$textname} /= $j; # Computes ratio rather than type count in case text is shorter than TTR size

  }
  
  ############################################################
  
   ## Output 1: Compute raw feature counts and write to table <prefix>_rawcounts.tsv
   
  open(FH, "> $Stat_dir/${prefix}_rawcounts.tsv") or die "Can't write file ${prefix}_rawcounts.tsv: $!";
  print FH join("\t", qw(Filename Words AWL TTR LDE), sort keys %counts), "\n"; 

  foreach my $i (0 .. $n_files - 1) {
    my $textname = $filenames[$i];

    printf FH "%s\t%d\t%.4f\t%.6f\t%.6f", $textname, $tokens[$i], $average_wl{$textname}, $ttr_h{$textname}, $lex_density{$textname};
    
    foreach $x (sort keys %counts) { # prints the frequencies for each tag
      if (exists ($counts{$x}{$textname})) {
        $counts{$x}{$textname} = $counts{$x}{$textname} # ELF: No normalisation, raw counts only.
      } else { # If there are no instances of that tag in this file it prints zero
        $counts{$x}{$textname} = 0;
      }
      print FH "\t$counts{$x}{$textname}";
    }
    
    print FH "\n";
  }

  close(FH);
  
  ############################################################

   # Output 2: Compute simple relative feature counts and write to table <prefix>_normed_100words_counts.tsv
   
  open(FH, "> $Stat_dir/${prefix}_normed_100words_counts.tsv") or die "Can't write file ${prefix}_normed_100words_counts.tsv: $!";
  print FH join("\t", qw(Filename Words AWL TTR LDE), sort keys %counts), "\n"; 

  %normed100 = ();
  foreach my $i (0 .. $n_files - 1) {
    my $textname = $filenames[$i];

    printf FH "%s\t%d\t%.4f\t%.6f\t%.6f", $textname, $tokens[$i], $average_wl{$textname}, $ttr_h{$textname}, $lex_density{$textname};
    
    foreach $x (sort keys %counts) { # prints the frequencies for each tag
	  if (exists ($counts{$x}{$textname})) {
        $normed100{$x}{$textname} = sprintf "%.4f", $counts{$x}{$textname} / $tokens[$i] * 100; # ELF: Normalisation per 100 words, rounded off to 4 decimals
        
      } else { # If there are no instances of that tag in this file it prints zero
        $normed100{$x}{$textname} = 0;
      }
      print FH "\t$normed100{$x}{$textname}";
    }
    
    print FH "\n";
  }

  close(FH);
  
  ############################################################

   ## Output 3: Compute custom relative feature counts and write to table <prefix>normed_complex_counts.tsv
  
	# List of features to be normalised per 100 nouns:
  # Shakir: noun semantic classes will be normalized per 100 nouns "NNHUMAN", "NNCOG", "NNCONC", "NNTECH", "NNPLACE", "NNQUANT", "NNGRP", "NNTECH", "NNABSPROC", "NOMZ", "NSTNCother"
  # Shakir: noun governed that clauses will be normalized per 100 nouns "ThNNFCT", "ThNATT", "ThNFCT", "ThNLIK", "ToNSTNC", "ToThNSTNCAll", "PrepNSTNC". THRCother is THRC minus TH_N clauses
  # Shakir: two sub classes of attributive adjectives "JJEPSTother", "JJATDother", also dependent on nouns. "JJATother" is JJAT minus the prev two classes
  # Shakir: STNCAll variables combine stance related sub class th and to clauses, either use individual or All counterparts "ThNSTNCAll"
   my @NNTnorm = ("DT", "JJAT", "POS", "NCOMP", "QUAN", "NNHUMAN", "NNCOG", "NNCONC", "NNTECH", "NNPLACE", "NNQUANT", "NNGRP", "NNABSPROC", "ThNNFCT", "ThNATT", "ThNFCT", "ThNLIK", "JJEPSTother", "JJATDother", "ToNSTNC", "PrepNSTNC", "JJATother", "ThNSTNCAll", "NOMZ", "NSTNCother", "JJDESCAll", "JJEpstAtdOther", "JJSIZE", "JJTIME", "JJCOLR", "JJEVAL", "JJREL", "JJTOPIC", "JJSTNCAllother");
  # Features to be normalised per 100 (very crudely defined) finite verbs:
  # Shakir: vb complement clauses of various sorts will be normalized per 100 verbs "ThVCOMM", "ThVATT", "ThVFCT", "ThVLIK", "WhVATT", "WhVFCT", "WhVLIK", "WhVCOM", "ToVDSR", "ToVEFRT", "ToVPROB", "ToVSPCH", "ToVMNTL", "VCOMMother", "VATTother", "VFCTother", "VLIKother"
  # Shakir: th jj clauses are verb gen verb dependant (pred adj) so "ThJATT", "ThJFCT", "ThJLIK", "ThJEVL", will be normalized per 100 verbs
  # Shakir: note THSCother and WHSCother are THSC and WHSC minus all new above TH and WH verb/adj clauses, "JJPRother" is JJPR without epistemic and attitudinal adjectives
  # Shakir: STNCAll variables combine stance related sub class th and to clauses, either use individual or All counterparts "ToVSTNCAll", "ToVSTNCother", "ThVSTNCAll", "ThVSTNCother", "ThJSTNCAll"
   my @FVnorm = ("ACT", "ASPECT", "CAUSE", "COMM", "CUZ", "CC", "CONC", "COND", "EX", "EXIST", "ELAB", "FREQ", "JJPR", "MENTAL", "OCCUR", "DOAUX", "QUTAG", "QUPR", "SPLIT", "STPR", "WHQU", "THSC", "WHSC", "CONT", "VBD", "VPRT", "PLACE", "PROG", "HGOT", "BEMA", "MDCA", "MDCO", "TIME", "THATD", "THRC", "VIMP", "MDMM", "ABLE", "MDNE", "MDWS", "MDWO", "XX0", "PASS", "PGET", "VBG", "VBN", "PEAS", "GTO", "FPP1S", "FPP1P", "TPP3S", "TPP3P", "SPP2", "PIT", "PRP", "RP", "ThVCOMM", "ThVATT", "ThVFCT", "ThVLIK", "WhVATT", "WhVFCT", "WhVLIK", "WhVCOM", "ToVDSR", "ToVEFRT", "ToVPROB", "ToVSPCH", "ToVMNTL", "JJPRother", "VCOMMother", "VATTother", "VFCTother", "VLIKother","ToVSTNCAll", "ThVSTNCAll", "ThJSTNCAll", "ThJATT", "ThJFCT", "ThJLIK", "ThJEVL", "ToVSTNCother", "FPPAll", "VNONPAST", "WHSCother", "THSCother", "THRCother", "MDPOSSCAll", "MDPREDAll", "PASSAll", "WhVSTNCAll", "VSTNCOtherAll"); 
   # All other features should be normalised per 100 words:
   my %Wnorm = ();
   
 	foreach $all (sort keys %counts) {
	 	my $add = 0;
 		foreach $nn ( @NNTnorm ) {
	 		if ($nn eq $all){
 				$add = 1;
 			}
	 	} 
	 	foreach $fv ( @FVnorm ) {
			if ($fv eq $all){
				$add = 1;
			}
		}
		if ($add == 0){
			$Wnorm{$all} = $counts{$all};
		}
 	}


 ## Compute "complex" custom relative feature counts and write to table <prefix>_normed_complex_counts.tsv
   open(FH, "> $Stat_dir/${prefix}_normed_complex_counts.tsv") or die "Can't write file ${prefix}_normed_complex_counts.tsv: $!";
   print FH join("\t", qw(Filename Words AWL TTR LDE), @NNTnorm, @FVnorm, sort(keys %Wnorm)), "\n";
   
  foreach my $i (0 .. $n_files - 1) {
     my $textname = $filenames[$i];
 
     printf FH "%s\t%d\t%.4f\t%.6f\t%.6f", $textname, $tokens[$i], $average_wl{$textname}, $ttr_h{$textname}, $lex_density{$textname};
 		
 
	%NNTnormresults = ();
	%FVnormresults = ();
	%Wnormresults = ();

 	foreach $y (@NNTnorm) {
 		if (exists ($counts{$y}{$textname}) && $counts{$y}{$textname} > 0 && $NTotal[$i] > 0) {
 			$NNTnormresults{$y}{$textname} = sprintf "%.4f", ($counts{$y}{$textname}/$NTotal[$i]) * 100;
 		} else {
 			$NNTnormresults{$y}{$textname} = 0;
 		}
 		print FH "\t$NNTnormresults{$y}{$textname}";
 	} 
 	foreach $y (@FVnorm) {
 		if (exists ($counts{$y}{$textname}) && $counts{$y}{$textname} > 0 && $VBTotal[$i] > 0) {
 			$FVnormresults{$y}{$textname} = sprintf "%.4f", $counts{$y}{$textname}/$VBTotal[$i] * 100;
 		} else {
 			$FVnormresults{$y}{$textname} = 0;
 		}
 		print FH "\t$FVnormresults{$y}{$textname}";
 	} 
 	foreach $y (sort keys %Wnorm) {
 		if (exists ($counts{$y}{$textname}) && $counts{$y}{$textname} > 0) {
 			$Wnormresults{$y}{$textname} = sprintf "%.4f", $counts{$y}{$textname}/$tokens[$i] * 100;
 		} else {
 			$Wnormresults{$y}{$textname} = 0;
 		}
 		print FH "\t$Wnormresults{$y}{$textname}";
 	} 			
 	
     print FH "\n";
  }
 
   close(FH);  

}