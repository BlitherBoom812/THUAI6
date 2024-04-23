#!/usr/local
python_dir=/usr/local/PlayerCode/CAPI/python/PyAPI
python_main_dir=/usr/local/PlayerCode/CAPI/python
playback_dir=/usr/local/output
map_dir=/usr/local/map
mkdir -p $playback_dir

TEAM_SEQ_ID=0 # default value
EXPOSED=0
SCORE_URL=www.baidu.com
MODE=0
GAME_TIME=100

get_current_team_label() {
    if [ $TEAM_SEQ_ID -eq $2 ]; then
        echo "find current team label: $1"
        current_team_label=$1
    fi
}

read_array() {
    callback=$1
    echo "read array: set callback command: $callback"
    
    IFS=':' read -r -a fields <<< "$2"

    count=0 # loop count

    for field in "${fields[@]}"
    do
        echo "parse field: $field"
        param0=$field
        
        # call command
        run_command="$callback $param0 $count"
        echo "Call Command: $run_command"
        $run_command

        count=$((count+1))
    done
}

if [ "$TERMINAL" = "SERVER" ]; then
    map_path=$map_dir/$MAP_ID.txt
    if [ $EXPOSED -eq 1 ]; then
        nice -10 ./Server --port 8888 --studentCount 4 --trickerCount 1 --resultFileName $playback_dir/result --gameTimeInSecond $GAME_TIME --mode $MODE --mapResource $map_path --url $SCORE_URL --token $TOKEN --fileName $playback_dir/video --startLockFile $playback_dir/start.lock > $playback_dir/server.log 2>&1 &
        server_pid=$!
    else
        echo "Run NO EXPOSED"
        nice -10 ./Server --port 8888 --studentCount 4 --trickerCount 1 --resultFileName $playback_dir/result --gameTimeInSecond $GAME_TIME --mode $MODE --mapResource $map_path --notAllowSpectator --url $SCORE_URL --token $TOKEN --fileName $playback_dir/video --startLockFile $playback_dir/start.lock > $playback_dir/server.log 2>&1 &
        server_pid=$!
        echo "server pid: $server_pid"
        ls $playback_dir
    fi

    sleep 100

    if [ -f $playback_dir/start.lock ]; then
        ps -p $server_pid
        while [ $? -eq 0 ]
        do
            sleep 1
            ps -p $server_pid > /dev/null 2>&1
        done
        # result=$(cat /usr/local/playback/result.json)
        # score0=$(echo "$result" | grep -oP '(?<="Student":)\d+')
        # score1=$(echo "$result" | grep -oP '(?<="Tricker":)\d+')
        # curl $URL -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"result":[{"team_id":0, "score":'${score0}'}, {"team_id":1, "score":'${score1}'}], "mode":'${MODE}'}'> $playback_dir/send.log 2>&1
        touch $playback_dir/finish.lock
        echo "Finish"
    else
        echo "Failed to start game."
        touch $playback_dir/finish.lock
        touch temp.lock
        mv -f temp.lock $playback_dir/video.thuaipb
        kill -9 $server_pid
    fi

elif [ "$TERMINAL" = "CLIENT" ]; then
    echo "Client Mode! Team Label data - $TEAM_LABEL"
    
    # parse team label name
    current_team_label=$TEAM_LABEL

    # k is an enum (1,2), 1 = STUDENT, 2 = TRICKER
    if [ "$current_team_label" = "Student" ]; then
        k=1
    elif [ "$current_team_label" = "Tricker" ]; then
        k=2
    else
        echo "Error: Invalid Team Label"
        exit
    fi
    pushd /usr/local/code
        if [ $k -eq 1 ]; then
            for i in {1..4}
            do
                j=$((i - 1)) # student player id from 0 to 3
                code_name=Student$i
                if [ -f "./$code_name.py" ]; then
                    echo "find ./$code_name.py"
                    cp -r $python_main_dir $python_main_dir$i
                    cp -f ./$code_name.py $python_main_dir$i/PyAPI/AI.py
                    nice -0 python3 $python_main_dir$i/PyAPI/main.py -I 127.0.0.1 -P 8888 -p $j > $playback_dir/team$k-player$j.log 2>&1 &
                    ps -aux |grep main.py
                elif [ -f "./$code_name" ]; then
                    echo "find ./$code_name"
                    nice -0 ./$code_name -I 127.0.0.1 -P 8888 -p $j > $playback_dir/team$k-player$j.log 2>&1 &
                    ps -aux |grep $code_name
                else
                    echo "ERROR. $code_name is not found."
                fi
            done
        else
            i=5
            j=4 # tricker id is 4
            code_name=Tricker
            if [ -f "./$code_name.py" ]; then
                echo "find ./$code_name.py"
                cp -r $python_main_dir $python_main_dir$i
                cp -f ./$code_name.py $python_main_dir$i/PyAPI/AI.py
                nice -0 python3 $python_main_dir$i/PyAPI/main.py -I 127.0.0.1 -P 8888 -p $j > $playback_dir/team$k-player$j.log 2>&1 &
                ps -aux |grep main.py
            elif [ -f "./$code_name" ]; then
                echo "find ./$code_name"
                nice -0 ./$code_name -I 127.0.0.1 -P 8888 -p $j > $playback_dir/team$k-player$j.log 2>&1 &
                ps -aux |grep $code_name
            else
                echo "ERROR. $code_name is not found."
            fi
        fi
        sleep $((GAME_TIME * 2))
    popd
else
    echo "VALUE ERROR: TERMINAL is neither SERVER nor CLIENT."
fi