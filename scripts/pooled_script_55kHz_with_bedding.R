# pooled script

# install sketchy if not installed
if (!requireNamespace("sketchy", quietly = TRUE)) {
    install.packages("sketchy")
}

## add 'developer/' to packages to install from github
x <- c(
    "maRce10/warbleR",
    "ranger",
    "maRce10/ohun"
)

sketchy::load_packages(x)

# function to convert seconds to min:s
seg_2_minseg <- function(seg) {
    minutos <- seg %/% 60
    segundos <- seg %% 60
    sprintf("%d:%02d", minutos, segundos)  # 2 digits
}

# where the original sound files are
sound_file_path <- "~/Descargas/sfs/"

# where to save the consolidated sound files and clips
consolidate_path <- "~/Descargas/sfs/"

# where to save the output data
output_data_path <- "~/Descargas/sfs/"

# set clip duration: 2 min
clip_duration <- 2 * 60

warbleR_options(wav.path = sound_file_path)

files <- list.files(
    path = sound_file_path,
    full.names = TRUE,
    recursive = TRUE,
    pattern = ".wav$|.wac$|.mp3$|.flac$"
)

dir.create(file.path(consolidate_path, "consolidated_sound_files"))

cns <- consolidate(
    path = sound_file_path,
    dest.path = file.path(consolidate_path, "consolidated_sound_files"),
    parallel = 1,
    file.ext = ".wav$|.flac$"
)

## Homogenize sound file format

# convert flac to wav
if (any(grepl("\\.flac$", files)))
    warbleR::wav_2_flac(path = file.path(consolidate_path, "consolidated_sound_files"), reverse = TRUE)

fix_wavs(samp.rate = 200, bit.depth = 16, path = file.path(consolidate_path, "consolidated_sound_files"))

warbleR_options(
    wav.path = file.path(consolidate_path, "consolidated_sound_files", "converted_sound_files")
)

## Split sound files into 5 min clips

# check files
feature_acoustic_data(path = .Options$warbleR$path)

ssf <- split_acoustic_data(sgmt.dur = clip_duration, cores = 1, path = .Options$warbleR$path)

write.csv(ssf, file.path(consolidate_path, "consolidated_sound_files", "converted_sound_files", "5min_clip_info.csv"), row.names = FALSE)

clips_path <- file.path(consolidate_path, "consolidated_sound_files", "converted_sound_files", "clips")

warbleR_options(
    wav.path = clips_path
)

## Automatic detection

detection <- energy_detector(
    path = .Options$warbleR$path,
    thinning = 0.5,
    bp = c(35, 90),
    smooth = 1,
    threshold = 2.5,
    hold.time = 3,
    min.duration = 1,
    max.duration = 200,
    cores = 1
)

saveRDS(
    detection,
    file.path(
        output_data_path,
        "detection.RDS"
    )
)

# Random forest classification
detection <- readRDS(file.path(output_data_path, "detection.RDS"))

# measure spectrographic parameters
spectral_features <- spectro_analysis(
    detection,
    bp = c(35, 85),
    fast = TRUE,
    ovlp = 70,
    parallel = 1
)

# check if any NA
sapply(spectral_features, function(x)
    sum(is.na(x)))

# remove NAs
detection <- detection[complete.cases(spectral_features), ]

spectral_features <- spectral_features[complete.cases(spectral_features), ]

# save acoustic parameters just in case
write.csv(
    spectral_features,
    file.path(output_data_path, "spectral_features.csv"),
    row.names = FALSE
)

## Predict based on pre-defined RF model
model_rds <- tempfile()

# this downloads the 55 kHz USV with bedding detection model
download.file(url = "https://figshare.com/ndownloader/files/57261971", destfile = model_rds, mode = "wb")

# read model
rf_model <- readRDS(model_rds)

# read acoustic features
spectral_features <- read.csv(
    file.path(output_data_path, "spectral_features.csv"),
    stringsAsFactors = FALSE
)

# apply model
detection$class <- predict(object = rf_model, data = spectral_features)$predictions

# keep only true positives
filtered_detection <- detection[detection$class == "true.positive", ]

saveRDS(
    filtered_detection,
    file.path(
        output_data_path,
        "random_forest_filtered_detection.RDS"
    )
)

## Summarized
# Reassemble detections to original sound files
# read detections
filtered_detection <- readRDS(file.path(output_data_path, "random_forest_filtered_detection.RDS"))

# read clip information
clip_info <- read.csv(
    file.path(
        consolidate_path,
        "consolidated_sound_files",
        "converted_sound_files",
        "5min_clip_info.csv"
    )
)

# reassemble to original (long) sound files
reass_detec <- reassemble_detection(detection = filtered_detection, Y = clip_info, pb = FALSE)

# counts per minute
## include files so it includes those with no detections
count_min <- acoustic_activity(
    X = reass_detec,
    time.window = 60,
    hop.size = 60,
    path =  file.path(consolidate_path, "/consolidated_sound_files/"),
    files = list.files(
        path = file.path(consolidate_path, "/consolidated_sound_files/"),
        pattern = "\\.wav$"
    )
)

# convert to minute rate
count_min$minute <- count_min$start / 60 + 1

wide_count_min <- reshape(count_min[, c("counts", "minute", "sound.files")],
                          direction = "wide",
                          idvar = "sound.files",
                          timevar = "minute")

names(wide_count_min) <- c("sound.files", paste("min", 1:max(count_min$minute)))

wide_count_min$total <- apply(wide_count_min[, -1], 1, sum, na.rm = TRUE)

# print results
wide_count_min

##  Minute with highest USV count
# counting
count_high_min <- acoustic_activity(
    X = reass_detec,
    time.window = 60,
    hop.size = 1,
    path = file.path(consolidate_path, "/consolidated_sound_files/")
)

# rate per minute
count_high_min$rate <- count_high_min$rate * 60

# get highest per sound file
sub_count_high_min <- count_high_min[count_high_min$duration == 60, ]

# get the row with the highest rate per sound file
highes_min <- do.call(rbind, lapply(split(sub_count_high_min, sub_count_high_min$sound.files), function(x)
    x[which.max(x$rate), ]))

highes_min$`start (min:s)` <- seg_2_minseg(highes_min$start)
highes_min$`end (min:s)` <- seg_2_minseg(highes_min$end)

# order columns
highes_min <- highes_min[, c(
    "sound.files",
    "start",
    "end",
    "start (min:s)",
    "end (min:s)",
    "duration",
    "counts",
    "rate"
)]

highes_min


