#!/bin/bash

# 默认值module
debug=0 # 调试等级
interactive_mode=false # 是否可交互
system_prompt="如果没有特别说明，请使用中文回答。" # 系统提示词
model="gpt-3.5-turbo"  # 默认模型
test=false
max_messages=40
declare -a messages
declare -a response

# 打印使用说明
print_usage() {
    echo "用法: $0 [选项] <消息内容>"
    echo ""
    echo "选项:"
    echo "  -u,  --url <url>       指定请求的URL"
    echo "  -s,  --secret <token>    指定 Token"
    echo "  -m,  --model <model-name>  指定 Model"
    echo "  -p,  --system-prompt <System Prompt> 指定系统提示"
    echo "  -t,  --test          测试延迟"
    echo "  -i,  --interactive -w "连接时间: %{time_connect}, 接收响应时间: %{time_starttransfer}\n"_mode    进入交互模式"
    echo "  --max-messages         设置最大携带消息数"
    echo "  -d,  --debug         打印调试信息"
    echo "  -dd, --debug-more       打印更多调试信息"
    echo "  -h,  --help          打印此帮助信息"
    echo ""
}

# 解析命令行参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -u|--url) url="$2/v1/chat/completions"; shift ;;
        -s|--secret) secret=$2; shift ;;
        -m|--module)    model=$2; shift ;;
        -p|--system-prompt) system_prompt=$2; shift ;;
        -t|--test)      test=true;;
        -i|--interactive) interactive_mode=true ;;  # 设置进入交互模式
        --max-messages) max_messages=$2; shift ;;
        -d|--debug) debug=1 ;;
        -dd|--debug-more) debug=2 ;;
        -h|--help) print_usage; exit 0 ;;
        *) content=$1 ;;  # 其余参数视为content
    esac
    shift
done
oneline(){
    # 获取终端宽度
    width=$(tput cols)

    # 打印分隔线
    printf -v line '%*s' "$width"
    echo "${line// /-}"
}
# 发送请求函数
send_request() {
    local messages=$1
    start_time=$(date +%s%N)  # 记录开始时间，精确到纳秒
    # 使用curl发送POST请求并获取响应
    response=$(curl -s  --request POST \
        --url "$url" \
        --header "Authorization: Bearer $secret" \
        --header 'content-type: application/json; charset=utf-8' \
        --data "$messages"| awk '{gsub(/\0/,"")}1')
    
    end_time=$(date +%s%N)  # 记录结束时间

    if [ "$(echo "$response" | jq 'has("error")')" = "true" ]; then

        case  $debug in
            1) echo "$LINENO行：$response" ;;
            2) echo "$LineNO行：$($response |jq .)" ;;
            *) result="$LINENO行：错误$(jq -r .error.code <<< "$response")：$(jq -r .error.message <<< "$response")"
                echo "$result" ;;

        esac
        exit 1
    fi
    
    

    # 根据debug的值决定输出格式
    case $debug in
        2) echo "$response" | jq -r .  ;;
        1) echo "$response" | jq -c '.choices[0].message'  ;; # 只输出内容，使用 -r 选项以避免引号
        *) echo -ne "\e[34m$(echo -n "$response" | jq -r '.choices[0].message.content' | tr -d '\n')\e[0m" ;;  # 只输出内容，使用 -r 选项以避免引号

    esac
    if [ $test == true ];then
        duration=$(( (end_time - start_time) / 1000000 ))  # 将纳秒转换为毫秒
        case $duration in
    [0-2000])
        echo -e "\e[32m     $duration ms\e[0m"
        ;;
    [3000-5000])
        echo -e "\e[33m     $duration ms\e[0m"
        ;;
    *)
        echo -e "\e[31m     $duration ms\e[0m"
        ;;
esac


    else 
        echo ''
    fi
    oneline
}

# 添加用户消息
add_user_message() {
    local content="$1"
    local user_message="{\"role\": \"user\", \"content\": \"$content\"}"
    messages+=("$user_message")
    if [ $debug -ne 0 ]; then 
        echo -n "$LINENO行==>" 
        echo $user_message |jq -c .
    fi
}


# 添加系统消息
add_system_message() {
    local content="$1"
    local sys_message="{\"role\": \"system\", \"content\": \"$content\"}"
    messages+=("$sys_message")
    if [ $debug -ne 0 ]; then 
        echo -n "$LINENO行==>" 
        # printf '%s\n' "${messages[@]}"
        echo $sys_message .
    fi
}

# 添加助手消息
add_assistant_message() {
    local content="$1"
    local ass_message="{\"role\": \"assistant\", \"content\": \"$content\"}"
    messages+=("$ass_message")
    if [ $debug -ne 0 ]; then 
        echo -n "$LINENO行==>" 
        echo $ass_message |jq -c .
    fi
}

# 生成 JSON 格式的 messages 数组
generate_messages_json() {
    # 将 messages 数组转换为 JSON 格式
    local json="{\"messages\": ["
    for ((i=0; i<${#messages[@]}; i++)); do
        json+="$(echo ${messages[i]}),"
    done
    json="${json%,}"  # 移除最后一个逗号
    json+="], \"model\": \"$model\"}"  # 添加 model 字段
    echo $json
}


init_messages() {
    messages=()
    if [ $debug -ne 0 ]; then 
        echo -n "$LINENO行==>" 
        echo -n $messages
        echo "初始化messges为空"

    fi
}

# 初始化对话历史
init_messages
add_system_message "$system_prompt"

# 如果没有提供content，且未指定交互模式，默认进入交互模式
if [ -n "$content" ]; then
    add_user_message $content

else 
    interactive_mode=true
fi

# 生成并输出 JSON
messages_json=$(generate_messages_json)
if [ $debug -ne 0 ]; then
    echo -n "$LINENO行==>"
    echo "$messages_json"
fi


# 进入交互模式
if $interactive_mode; then
    echo "进入对话模式。输入 '/exit' 退出，输入 '/clean' 清除上下文。"
    while true; do
        read -p "你: " content agrument
        if [[ "$content" == "/exit" ]]; then
            break
        elif [[ "$content" == "/messages" ]]; then
            messages_json=$(generate_messages_json)
            echo $messages_json |jq .messages
            echo $messages_json |jq '.messages|length'
        elif [[ "$content" == "/model" ]]; then
            model=$agrument
            echo $model
        elif [[ "$content" == "/url" ]]; then
            url="$agrument/v1/chat/completions"
            echo $url
        elif [[ "$content" == "/token" ]]; then
            token=$agrument
            echo $token
        elif [[ "$content" == "/test" ]]; then
            if [ "$test" = true ]; then
                test=false
            else
                test=true
            fi
        elif [[ "$content" == "/clean" ]]; then
            init_messages
            add_system_message "$system_prompt"
            echo "上下文已清除。"
        elif [[ "$content" == "/help" ]]; then
            echo "指令格式： /<commend> <agrument>"
            oneline
            echo "/messages 打印历史消息"
            echo "/model <model name>   切换模型"
            echo "/url <base url>   改变url"
            echo "/token <token>    改变token"
            echo "/test     是/否打印耗时"
            echo "/clean    清除历史信息"
            echo "/exit     退出"
            oneline
        else
            # 将用户输入添加到消息历史中
            add_user_message "$content"
            # 生成并输出 JSON
            messages_json=$(generate_messages_json)
            # 发送请求并获取响应
            send_request "$messages_json"
            message="$(echo $response |jq -r .choices[0].message.content)"
            # 将助手的响应添加到消息历史中
            add_assistant_message "$message"
        fi
        content=""  # 清空content以便下次输入
    done

else
    # 发送请求
    messages_json=$(generate_messages_json)
    send_request "$messages_json"
    oneline
fi
