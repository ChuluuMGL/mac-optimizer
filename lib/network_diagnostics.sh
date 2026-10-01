#!/usr/bin/env bash
# Read-only, opt-in connectivity checks. Output never includes local IPs,
# Wi-Fi SSIDs, proxy endpoints, or DNS server addresses.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

NETWORK_DNS_SUCCESSES=0
NETWORK_HTTP_RESPONSES=0
NETWORK_DIRECT_RESPONSES=0
NETWORK_PROXY_RESPONSES=0

network_scutil_value() {
  local key="$1"
  local config="$2"
  printf '%s\n' "$config" | awk -v key="$key" '$1 == key && $2 == ":" { print $3; exit }'
}

network_dns_probe() {
  local host="$1"
  local output

  if ! command -v dscacheutil >/dev/null 2>&1; then
    printf '命令不可用'
    return
  fi

  output="$(scan dscacheutil -q host -a name "$host" 2>/dev/null || true)"
  if printf '%s\n' "$output" | awk '/^(ip_address|ipv6_address):[[:space:]]*[^[:space:]]+/{found=1} END{exit !found}'; then
    NETWORK_DNS_SUCCESSES=$((NETWORK_DNS_SUCCESSES + 1))
    printf '成功'
  else
    printf '未解析到地址'
  fi
}

network_curl_probe() {
  local label="$1"
  local url="$2"
  local route_kind="$3"
  shift 3

  local metrics status elapsed state
  metrics="$(scan curl --head --silent --output /dev/null \
    --connect-timeout 4 --max-time 8 \
    --write-out '%{http_code}|%{time_total}' "$@" "$url" 2>/dev/null || true)"
  status="${metrics%%|*}"
  elapsed="${metrics#*|}"

  if [[ "$status" =~ ^[1-5][0-9][0-9]$ ]]; then
    state="已收到 HTTP 响应"
    NETWORK_HTTP_RESPONSES=$((NETWORK_HTTP_RESPONSES + 1))
    case "$route_kind" in
      direct) NETWORK_DIRECT_RESPONSES=$((NETWORK_DIRECT_RESPONSES + 1)) ;;
      proxy) NETWORK_PROXY_RESPONSES=$((NETWORK_PROXY_RESPONSES + 1)) ;;
    esac
  else
    status="无响应"
    elapsed="—"
    state="未连通或超时"
  fi

  if [[ -n "$elapsed" && "$elapsed" != "—" ]]; then
    printf -- '- %s：%s（HTTP %s，耗时 %ss）\n' "$label" "$state" "$status" "$elapsed"
  else
    printf -- '- %s：%s\n' "$label" "$state"
  fi
}

network_run_diagnostics() {
  local route_info gateway interface ping_output ping_stats loss rtt
  local dns_apple dns_cloudflare proxy_config pac_enabled https_enabled socks_enabled
  local proxy_host proxy_port proxy_authority proxy_kind

  route_info="$(scan route -n get default 2>/dev/null || true)"
  gateway="$(printf '%s\n' "$route_info" | awk -F':[[:space:]]*' '/gateway:/{print $2; exit}')"
  interface="$(printf '%s\n' "$route_info" | awk -F':[[:space:]]*' '/interface:/{print $2; exit}')"

  if [[ -n "$interface" ]]; then
    printf -- '- 默认路由：已检测（接口 %s）\n' "$interface"
  else
    printf -- '- 默认路由：未能读取\n'
  fi

  if [[ -n "$gateway" ]] && command -v ping >/dev/null 2>&1; then
    ping_output="$(scan ping -n -c 5 -W 1000 "$gateway" 2>/dev/null || true)"
    ping_stats="$(printf '%s\n' "$ping_output" | awk -F', ' '/packets transmitted/{split($1,tx," "); split($2,rx," "); loss=$3; sub(/ packet loss.*/,"",loss); printf "%s/%s 包收到，丢包 %s",rx[1],tx[1],loss; exit}')"
    rtt="$(printf '%s\n' "$ping_output" | awk '/round-trip min\/avg\/max\/stddev|rtt min\/avg\/max\/mdev/{split($4,parts,"/"); print parts[2]; exit}')"
    if [[ -n "$ping_stats" ]]; then
      if [[ -n "$rtt" ]]; then
        printf -- '- 默认网关 ICMP：%s，平均往返 %sms\n' "$ping_stats" "$rtt"
      else
        printf -- '- 默认网关 ICMP：%s\n' "$ping_stats"
      fi
    else
      printf -- '- 默认网关 ICMP：无回应或 ICMP 被拦截\n'
    fi
  else
    printf -- '- 默认网关 ICMP：未能探测\n'
  fi

  dns_apple="$(network_dns_probe apple.com)"
  dns_cloudflare="$(network_dns_probe cloudflare.com)"
  [[ "$dns_apple" == "成功" ]] && NETWORK_DNS_SUCCESSES=$((NETWORK_DNS_SUCCESSES + 1))
  [[ "$dns_cloudflare" == "成功" ]] && NETWORK_DNS_SUCCESSES=$((NETWORK_DNS_SUCCESSES + 1))
  printf -- '- macOS DNS 解析：apple.com %s；cloudflare.com %s（可能命中系统缓存）\n' "$dns_apple" "$dns_cloudflare"

  if command -v curl >/dev/null 2>&1; then
    network_curl_probe '直连 Apple' 'https://www.apple.com/' direct --noproxy '*'
    network_curl_probe '直连 Cloudflare' 'https://www.cloudflare.com/' direct --noproxy '*'
  else
    printf -- '- HTTPS 探测：curl 命令不可用\n'
  fi

  proxy_config="$(scan scutil --proxy 2>/dev/null || true)"
  if [[ -z "$proxy_config" ]]; then
    printf -- '- macOS 系统代理：状态不可读取，未单独测试代理路径\n'
  else
    pac_enabled="$(network_scutil_value ProxyAutoConfigEnable "$proxy_config")"
    https_enabled="$(network_scutil_value HTTPSEnable "$proxy_config")"
    socks_enabled="$(network_scutil_value SOCKSEnable "$proxy_config")"
    proxy_host=""
    proxy_port=""
    proxy_kind=""

    if [[ "$pac_enabled" == "1" ]]; then
      printf -- '- macOS 系统代理：已启用 PAC 自动代理；本检查不执行 PAC 脚本，代理路径未单独验证\n'
    elif [[ "$https_enabled" == "1" ]]; then
      proxy_host="$(network_scutil_value HTTPSProxy "$proxy_config")"
      proxy_port="$(network_scutil_value HTTPSPort "$proxy_config")"
      # macOS HTTPSProxy describes the HTTP CONNECT proxy endpoint, not an
      # HTTPS transport to the proxy itself.
      proxy_kind="http"
    elif [[ "$socks_enabled" == "1" ]]; then
      proxy_host="$(network_scutil_value SOCKSProxy "$proxy_config")"
      proxy_port="$(network_scutil_value SOCKSPort "$proxy_config")"
      proxy_kind="socks5h"
    elif [[ "$(network_scutil_value HTTPEnable "$proxy_config")" == "1" ]]; then
      proxy_host="$(network_scutil_value HTTPProxy "$proxy_config")"
      proxy_port="$(network_scutil_value HTTPPort "$proxy_config")"
      proxy_kind="http"
    fi

    if [[ -n "$proxy_kind" && -n "$proxy_host" && -n "$proxy_port" ]]; then
      if [[ "$proxy_host" == *:* && "$proxy_host" != \[*\] ]]; then
        proxy_authority="[$proxy_host]:$proxy_port"
      else
        proxy_authority="$proxy_host:$proxy_port"
      fi
      network_curl_probe '当前系统代理（地址隐藏）' 'https://www.apple.com/' proxy \
        --proxy "$proxy_kind://$proxy_authority"
    elif [[ -n "$proxy_kind" ]]; then
      printf -- '- macOS 系统代理：已启用但未读取到完整地址/端口，未能验证\n'
    else
      printf -- '- macOS 系统代理：未检测到已启用的 HTTPS/HTTP/SOCKS 代理\n'
    fi
  fi

  if [[ "$NETWORK_DNS_SUCCESSES" -gt 0 && "$NETWORK_HTTP_RESPONSES" -gt 0 ]]; then
    if [[ "$NETWORK_DIRECT_RESPONSES" -gt 0 && "$NETWORK_PROXY_RESPONSES" -gt 0 ]]; then
      printf -- '- 综合判断：本次抽样中 DNS、直连和已配置代理均有响应，未见整体断网。\n'
    elif [[ "$NETWORK_DIRECT_RESPONSES" -gt 0 ]]; then
      printf -- '- 综合判断：本次抽样中 DNS 和至少一个直连 HTTPS 目标有响应，未见整体断网。\n'
    else
      printf -- '- 综合判断：本次抽样中 DNS 和代理 HTTPS 有响应；直连路径可能受网络策略限制。\n'
    fi
  elif [[ "$NETWORK_DNS_SUCCESSES" -eq 0 ]]; then
    printf -- '- 综合判断：系统 DNS 未解析到测试域名；需结合当前网络、VPN/代理和 DNS 策略进一步判断。\n'
  else
    printf -- '- 综合判断：DNS 有响应但 HTTPS 探测未收到响应；可能是代理、防火墙或目标站点限制。\n'
  fi

  printf -- '- 说明：这是一次短时可达性抽样；不测带宽、不评估持续稳定性、不修改网络设置，结果也不计入磁盘健康分。\n'
}

network_run_diagnostics
