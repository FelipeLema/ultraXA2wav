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

if [[ $# -ne 2 ]]
then
    echo " ax2flac FROMDIR DESTDIR"
    exit
fi

FROMDIR="$1"
shift
DESTDIR="$1"
function stitch_to_flac
{
    in1_f="$1" 
    if [[ "$in1_f" == $FROMDIR/*\[2\]* ]]
    then
        #skip
        return
    fi
    in2_f=$(sed 's/\[1\]/[2]/g' <<<$in1_f)
    #convert 1 to wav
    wav1="$DESTDIR/${in1_f:t:r}.wav"
    echo $wav1
    ffmpeg -i "$in1_f" -ar 37800 -acodec pcm_s16le "$wav1"
    #convert 2 to wav
    wav2="$DESTDIR/${in2_f:t:r}.wav"
    echo $wav2
    ffmpeg -i "$in2_f" -ar 37800 -acodec pcm_s16le "$wav2"
    #convert 2 to wav with fade out
    wav3="$DESTDIR/${in2_f:t:r}_fadeout.wav"
    echo $wav3
    ffmpeg -i "$in2_f" -ar 37800 -acodec pcm_s16le \
        -t 8 -af afade=t=out:d=8 \
        "$wav3"

    #concat them
    wavout="${wav2// \[2\]/}"
    cat <(echo "file '$wav1'\nfile '$wav2'\nfile '$wav2'\nfile '$wav2'\nfile '$wav3'") > l.tmp
    echo $wavout
    ffmpeg -f concat -i l.tmp -acodec flac "${wavout:r}.flac"
    
    #clean up
    rm $wav1
    rm $wav2
    rm $wav3
    rm l.tmp
    #rm $wavout

}

for in1_f in $FROMDIR/*XA
do
    if [[ "$in1_f" == $FROMDIR/*\[[[:digit:]]\]* ]]
    then
        stitch_to_flac "$in1_f"
    else
        #convert 1 to flac
        flac1="$DESTDIR/${in1_f:t:r}.flac"
        echo "$flac1"
        ffmpeg -i "$in1_f" -acodec flac "$flac1"
    fi

done
