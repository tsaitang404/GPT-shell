原本是写来测试OpenAI接口的，加了交互功能，可以用shell简单的与ghatGPT对话。
url请输入完整，openai需要带有v1/chat/completions
cloudflare llama完整地址形如https://api.cloudflare.com/client/v4/accounts/<token>/ai/run/@cf/meta/llama-3-8b-instruct
## Help
```
给执行权限 chmod +x gptshell.sh
用法: gptshell.sh [选项] <消息内容>
选项:
  -u,  --url <url>         指定请求的URL
  -s,  --secret <token>    指定 Token
  -m,  --model             指定模型
  -f,  --filter            指定过滤器openai|cloudflare
  -t,  --test              显示请求总时间
  -p,  --system-prompt     改变系统提示
  -i,  --interactive_mode  进入交互模式
  -d,  --debug             打印调试信息
  -dd, --debug-more        打印更多调试信息
  -h,  --help              打印此帮助信息
```
## Todo
- ~~`-m|--model`选择模型~~
- ~~shell内改变模型`/model`~~
- ~~`-p|--system-prompt`改变系统提示~~
- ~~`/system_prompt`shell内改变系统prompt~~
- ~~shell内改变url和token~~
- ~~shell内帮助`/help`~~
- ~~`-t|--testuel` url测速~~
- ~~优化逻辑，支持Github Llama AI~~
- 携带历史消息数量
- 历史消息压缩
- 简单tui
