#!/bin/bash

# 默认值module
debug=0 # 调试等级
interactive_mode=false # 是否可交互
system_prompt="如果没有特别说明，请使用中文回答。" # 系统提示词
model="gpt-3.5-turbo"  # 默认模型

# 打印使用说明
print_usage() {
    echo "用法: $0 [选项] <消息内容>"
    echo ""
    echo "选项:"
    echo "  -u,  --url <url>       指定请求的URL"
    echo "  -s,  --secret <token>    指定 Token"
    echo "  -m,  --model <model-name>  指定 Model"
    echo "  -i,  --interactive_mode    进入交互模式"
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
        -d|--debug) debug=1 ;;
        -dd|--debug-more) debug=2 ;;
        -i|--interactive) interactive_mode=true ;;  # 设置进入交互模式
        -m|--module)    model=$2; shift ;;
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
    # 使用curl发送POST请求并获取响应
    response=$(curl -s  --request POST \
        --url "$url" \
        --header "Authorization: Bearer $secret" \
        --header 'content-type: application/json; charset=utf-8' \
        --data "$messages"| awk '{gsub(/\0/,"")}1')

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
        *) echo "$response" | jq -r '.choices[0].message.content'  ;;  # 只输出内容，使用 -r 选项以避免引号

    esac
}

# 添加用户消息
add_user_message() {
    local content=$1
    local user_message="{\"role\": \"user\", \"content\": \"$content\"}"
    messages+=("$user_message")
    if [ $debug -ne 0 ]; then 
        echo -n "$LINENO行==>" 
        echo $user_message |jq -c .
    fi
}


# 添加系统消息
add_system_message() {
    local content=$1
    local sys_message="{\"role\": \"system\", \"content\": \"$content\"}"
    messages+=("$sys_message")
    if [ $debug -ne 0 ]; then 
        echo -n "$LINENO行==>" 
        # printf '%s\n' "${messages[@]}"
        echo $sys_message |jq -c .
    fi
}

# 添加助手消息
add_assistant_message() {
    local content=$1
    local ass_message="{\"role\": \"assistent\", \"content\": \"$content\"}"
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
fi


# 进入交互模式
if $interactive_mode; then
    echo "进入对话模式。输入 '/exit' 退出，输入 '/clean' 清除上下文。"
    while true; do
        read -p "你: " content agrument
        if [[ "$content" == "/exit" ]]; then
            break
        elif [[ "$content" == "/messages" ]]; then
            echo $messages |jq .
        elif [[ "$content" == "/model" ]]; then
            model=$agrument
            echo $model
        elif [[ "$content" == "/clean" ]]; then
            init_messages
            add_system_message "$system_prompt"
            echo "上下文已清除。"
        elif [[ "$content" == "/help" ]]; then
            print_usage
        else
            # 将用户输入添加到消息历史中
            add_user_message "$content"

            # 生成并输出 JSON
            export messages_json=$(generate_messages_json)
            # 发送请求并获取响应
            response=$(send_request "$messages_json")

            echo $response
            oneline
            # 将助手的响应添加到消息历史中
            add_system_message $response
        fi
        content=""  # 清空content以便下次输入
    done

else
    # 发送请求
    messages_json=$(generate_messages_json)
    send_request "$messages_json"
    oneline
fi
