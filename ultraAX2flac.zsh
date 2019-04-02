#!/usr/bin/env zsh
# Simple converter that takes .XA files (PSX /playstation)
# from a directory and converts them to flac
#
# I'm not very fond of 2-reps-then-fadeout standard
# for vgm, so I put 3-reps-then-fadeout.
# Assumes that rep-files are called XX[1].XA and XX[2].XA
# the last one being the repetition.
# 
# Thanks to whoever wrote this post
# http://www.momentaryfascinations.com/technology/the.spyro.soundtracks.html
#
# Just for the record: if you happen to have _that_ SotN XA rip
# that has _that_ messed up Golden Dance (Dance of Gold) version
# modify wav2 to be 1m40s long (-t 00:01:40)

set -e


# ffmpeg has some quoting issues
quote_file()
{
    local f=$1
    #        ↓ I don't think anyone uses non-ASCII characters in this context
    sed "s/'/ψ/g" <<< $f
}
stitch_to_flac()
{
    local in1_f="$1" 
    if [[ $in1_f == *\[2\]* ]]
    then
        #skip
        return
    fi
    local in2_f=$(sed 's/\[1\]/[2]/g' <<<$in1_f)
    #convert 1 to wav
    local wav1=$(quote_file "$DESTDIR/${in1_f:t:r}.wav") 
    rm -f $wav1
    ffmpeg -i "$in1_f" -ar 37800 -acodec pcm_s16le "$wav1"
    #convert 2 to wav
    local wav2=$(quote_file "$DESTDIR/${in2_f:t:r}.wav")
    rm -f $wav2
    local golden_dance_extra_args=($(
    if [[ $in1_f == *Golden*Dance* ]]; then
        print - -t 00:01:40
    fi
        ))
    ffmpeg -i "$in2_f" -ar 37800 -acodec pcm_s16le $golden_dance_extra_args[@] "$wav2"
    #convert 2 to wav with fade out
    local wav3=$(quote_file "$DESTDIR/${in2_f:t:r}_fadeout.wav")
    rm -f $wav3
    ffmpeg -i "$in2_f" -ar 37800 -acodec pcm_s16le \
        -t 8 -af afade=t=out:d=8 \
        "$wav3"

    #concat them
    local list_of_singles=l.tmp.txt
    echo -n >! $list_of_singles # ensure file exists and is empty
    local singles=($wav1 
                   $wav2 $wav2 $wav2  # 3 reps
                   $wav3
                   )
    for f in ${singles[@]}; do
            print "file '$f'" >> $list_of_singles
    done
    local out_original="$DESTDIR/${in2_f:t:r}"
    local out_sans_brackets="${out_original// \[2\]/}"
    local flacout="${out_sans_brackets:r}.flac"
    rm -f $flacout
    ffmpeg -f concat -safe 0 -i $list_of_singles -acodec flac $flacout

    #clean up
    rm $wav1
    rm $wav2
    rm $wav3
    rm $list_of_singles
    #rm $wavout

}

_main()
{
    if [[ $# -ne 2 ]]
    then
        >&2 print ${(%):-%x} FROMDIR DESTDIR
        exit -1
    fi

    local FROMDIR=$1
    local DESTDIR=$2
    mkdir -p $DESTDIR

    setopt extendedglob
    for in1_f in $FROMDIR/*XA
    do
        if [[ $in1_f == $FROMDIR/*\[[[:digit:]]\]* ]]
        then
            stitch_to_flac ${in1_f:A}
        else
            #convert 1 to flac
            flac1="$DESTDIR/${in1_f:t:r}.flac"
            ffmpeg -i "$in1_f" -acodec flac "$flac1"
        fi

    done
}


_main $@
