#!/bin/sh
# verify-plan.sh - check a plan file against plan format v1.
# Usage: verify-plan.sh [plan-file]   (default: resolve .claude/plan/*.md, else PLAN.md)
# Exits 0 if conformant or absent, 1 on any violation.
#
# LOCAL ONLY, not a CI check: the plan and the PRD live under .claude/, which is
# gitignored, so on a fresh clone they do not exist. An absent plan is a private
# context that was never shared, not a violation, so it exits 0.
set -eu

fail=0
warn()  { printf 'PLAN: %s\n' "$1" >&2; fail=1; }
note()  { printf 'PLAN: warning: %s\n' "$1" >&2; }

# --- resolve the plan --------------------------------------------------------
PLAN="${1:-}"
if [ -z "$PLAN" ]; then
  n=0
  for f in .claude/plan/*.md; do
    [ -e "$f" ] || continue
    grep -q '^- Status: todo' "$f" 2>/dev/null || continue
    n=$((n+1)); PLAN="$f"
  done
  if [ "$n" -gt 1 ]; then
    echo "PLAN: several plans under .claude/plan/ carry a todo phase; name one explicitly" >&2
    exit 1
  fi
  [ -n "$PLAN" ] || { for f in .claude/plan/*.md; do [ -e "$f" ] && PLAN="$f" && break; done; }
  [ -n "$PLAN" ] || { [ -f PLAN.md ] && PLAN=PLAN.md; }
fi

[ -n "$PLAN" ] && [ -f "$PLAN" ] || { echo "PLAN: no plan file (private context, not shared), ok"; exit 0; }

PRD="${PRD:-.claude/project/prd.md}"
UX="${UX:-docs/ux.md}"
ADR="${ADR:-docs/adr}"

# --- per-phase field extraction ---------------------------------------------
# One record per phase: id<TAB>field<TAB>value
phases=$(awk '
  # A phase heading is "## <id> - <goal>": an id with no space, then " - ".
  # Any other ## section (Log, Constats, notes) is prose and must not be parsed
  # as a phase, or its title gets split into one bogus phase per word.
  /^## / {
    line=$0; sub(/^## /,"",line)
    cur=""
    if (line ~ /^[A-Za-z][A-Za-z0-9_.-]*[ \t]+-[ \t]+/) {
      id=line; sub(/[ \t]+-[ \t]+.*$/,"",id)
      cur=id; printf "%s\tPHASE\t%s\n", id, line
    }
    next
  }
  cur!="" && /^- [A-Za-z][A-Za-z ]*:/ {
    line=$0; sub(/^- /,"",line)
    i=index(line,":")
    k=substr(line,1,i-1); v=substr(line,i+1)
    gsub(/^[ \t]+|[ \t]+$/,"",v)
    printf "%s\t%s\t%s\n", cur, k, v
  }
' "$PLAN")

ids=$(echo "$phases" | awk -F'\t' '$2=="PHASE"{print $1}')
[ -n "$ids" ] || { echo "PLAN: $PLAN has no phase yet, ok"; exit 0; }

field() { echo "$phases" | awk -F'\t' -v i="$1" -v k="$2" '$1==i && $2==k {print $3; exit}'; }
has()   { echo "$phases" | awk -F'\t' -v i="$1" -v k="$2" '$1==i && $2==k {f=1} END{exit !f}'; }

# --- id uniqueness across the repo -------------------------------------------
# Ids are repo-unique (plan format: Phase ids). Warning only, never blocking:
# plans written before that rule legitimately hold duplicates, and the script
# cannot tell a grandfathered id from a misallocated one. Enforcement is `add`,
# which allocates max+1 over active plans and archives.
plandir=$(dirname "$PLAN")
ARCHIVES="${ARCHIVES:-.claude/project/archives}"
for f in "$plandir"/*.md "$ARCHIVES"/*.md; do
  [ -e "$f" ] && [ "$f" != "$PLAN" ] || continue
  dups=""
  for id in $ids; do
    grep -qE "^## $id[ \t]+-[ \t]+" "$f" && dups="$dups $id"
  done
  [ -n "$dups" ] \
    && note "ids$dups also exist in $f (ids are repo-unique; new phases allocate max+1 over plans and archives)"
done

# --- placeholders ------------------------------------------------------------
grep -nE '<[a-z][a-z .|/]*>|\{\{' "$PLAN" | grep -v '^\s*[0-9]*:.*Status legend' >/dev/null 2>&1 \
  && warn "$PLAN still carries a <placeholder> or {{template}}" || true

# --- per-phase checks --------------------------------------------------------
for id in $ids; do
  # Status
  st=$(field "$id" Status)
  case "$st" in
    todo|backlog|doing|verified|blocked) ;;
    "") warn "$id: no Status line" ;;
    *)  warn "$id: status '$st' is outside todo|backlog|doing|verified|blocked" ;;
  esac

  # Accept
  has "$id" Accept || warn "$id: no Accept line (a phase no command can decide is not a phase)"

  # New deps
  has "$id" "New deps" || warn "$id: no 'New deps' line (use none)"

  # Depends on: every named phase must exist
  dep=$(field "$id" "Depends on")
  case "$dep" in ""|none|None|NONE) ;; *)
    for d in $(echo "$dep" | tr ',' ' '); do
      [ -n "$d" ] || continue
      echo "$ids" | grep -qxF "$d" || warn "$id: depends on $d, which is not a phase in this plan"
      dst=$(field "$d" Status)
      [ "$dst" = "backlog" ] && [ "$st" = "todo" ] \
        && note "$id is todo but depends on $d which is in backlog: the loop will skip it forever"
    done ;;
  esac

  # Refs
  if ! has "$id" Refs; then
    note "$id has no Refs line (use none if nothing justifies it)"
  else
    refs=$(field "$id" Refs)
    case "$refs" in ""|none|None|NONE)
      note "$id: Refs is none, nothing recorded justifies this phase" ;;
    *)
      for r in $(echo "$refs" | tr ',' ' '); do
        [ -n "$r" ] || continue
        case "$r" in
          R[0-9]*)
            [ -f "$PRD" ] || { note "$id: $r cannot be resolved, no $PRD"; continue; }
            grep -qE "^\|[ \t]*\**$r\**[ \t]*\|" "$PRD" \
              || warn "$id: $r is not a row in $PRD" ;;
          ADR-[0-9]*)
            num=${r#ADR-}
            f=$(ls "$ADR/$num"-*.md 2>/dev/null | head -1 || true)
            if [ -z "$f" ]; then
              warn "$id: $r has no file under $ADR/"
            else
              adrst=$(awk 'NR==1&&$0!="---"{exit} NR==1{next} /^---/{exit} /^status:/{sub(/^status:[ \t]*/,"");print;exit}' "$f")
              case "$adrst" in
                superseded|deprecated) warn "$id: references $r whose status is $adrst" ;;
              esac
            fi ;;
          UX:*)
            scr=${r#UX:}
            [ "$scr" = "system" ] && continue
            [ -f "$UX" ] || { warn "$id: $r cannot be resolved, no $UX"; continue; }
            grep -qE "^\|[ \t]*\**$scr\**[ \t]*\|" "$UX" \
              || warn "$id: screen '$scr' is not a row in $UX" ;;
          GH-[0-9]*) : ;;   # never resolved: needs network and a token, would break offline determinism
          *) warn "$id: reference '$r' has no known prefix (R / ADR- / UX: / GH- / none)" ;;
        esac
      done ;;
    esac
  fi

  # A phase whose scope touches the UI must carry a UX ref.
  if [ -f "$UX" ]; then
    up=$(awk 'NR==1&&$0!="---"{exit} NR==1{next} /^---/{exit} /^ui_paths:/{sub(/^ui_paths:[ \t]*/,"");print;exit}' "$UX")
    scope=$(field "$id" Scope)
    if [ -n "$up" ] && [ -n "$scope" ]; then
      touches=0
      for p in $(echo "$up" | tr ',' ' '); do
        base=$(echo "$p" | sed 's#/\*\*.*$##; s#/\*.*$##')
        [ -n "$base" ] || continue
        case "$scope" in *"$base"*) touches=1 ;; esac
      done
      if [ "$touches" -eq 1 ]; then
        echo "$(field "$id" Refs)" | grep -q 'UX:' \
          || warn "$id: scope touches ui_paths but carries no UX: ref (use UX:system for a cross-cutting change)"
      fi
    fi
  fi

  # Bugfix phases: Repro must not be empty.
  if has "$id" Repro; then
    [ -n "$(field "$id" Repro)" ] \
      || warn "$id: Repro is empty (without a reproduction there is no bug, only an impression)"
  fi
done

# --- dependency cycles -------------------------------------------------------
cyc=$(echo "$phases" | awk -F'\t' '
  $2=="PHASE" { ids[$1]=1; next }
  $2=="Depends on" {
    v=$3
    if (v=="none"||v=="None"||v=="NONE"||v=="") next
    n=split(v, d, ",")
    for (i=1;i<=n;i++) { gsub(/^[ \t]+|[ \t]+$/,"",d[i]); if (d[i]!="") dep[$1]=dep[$1] " " d[i] }
  }
  END {
    for (a in ids) {
      # depth-bounded walk; a cycle re-reaches the start
      split(dep[a], q, " "); qn=0
      for (i in q) if (q[i]!="") { qn++; queue[qn]=q[i] }
      seen=""; head=1
      while (head<=qn && qn<500) {
        c=queue[head++]
        if (c==a) { print a; break }
        if (index(seen, " " c " ")>0) continue
        seen=seen " " c " "
        split(dep[c], r, " ")
        for (i in r) if (r[i]!="") { qn++; queue[qn]=r[i] }
      }
    }
  }
')
[ -z "$cyc" ] || { for c in $cyc; do warn "$c: dependency cycle"; done; }

# --- log: one phase, one commit ----------------------------------------------
# Two phases sharing a changeset id in the Log is the trace of a missed `jj new`
# between turns: the second phase amended the first one's described commit. It
# costs a jj split every time; catching it here makes the repair immediate.
shared=$(awk '
  /^## Log/ { inlog=1; next }
  inlog && /^## / { inlog=0 }
  inlog {
    n=split($0, f, "|"); if (n<3) next
    id=f[1]; gsub(/[ \t]/,"",id); if (id !~ /^[A-Za-z][A-Za-z0-9_.-]*$/ || id=="") next
    cid=f[3]; gsub(/[ \t]/,"",cid)
    if (cid=="" || cid=="none" || cid=="-" || cid ~ /aucun/) next
    key=cid SUBSEP id
    if (!(key in seen)) { seen[key]=1; ph[cid]=ph[cid] " " id; cnt[cid]++ }
  }
  END { for (c in cnt) if (cnt[c]>1) printf "%s:%s\n", c, ph[c] }
' "$PLAN")
if [ -n "$shared" ]; then
  echo "$shared" | while IFS=: read -r cid plist; do
    warn "log: phases$plist share changeset $cid (one phase, one commit: jj split, then correct the Log)"
  done
  fail=1
fi

# --- PRD coverage ------------------------------------------------------------
if [ -f "$PRD" ]; then
  allrefs=$(echo "$phases" | awk -F'\t' '$2=="Refs"{print $3}' | tr ',' '\n' | sed 's/^[ \t]*//; s/[ \t]*$//')
  awk -F'|' '/^\|[ \t]*\**R[0-9]+\**[ \t]*\|/ {
      id=$2; gsub(/^[ \t]+|[ \t]+$|\*/,"",id)
      pri=$4; gsub(/^[ \t]+|[ \t]+$/,"",pri)
      sta=$5; gsub(/^[ \t]+|[ \t]+$/,"",sta)
      if (tolower(pri)=="must" && tolower(sta)!="done" && tolower(sta)!="dropped") print id
    }' "$PRD" | while read -r rid; do
      [ -n "$rid" ] || continue
      echo "$allrefs" | grep -qxF "$rid" || note "$rid is a must requirement with no phase serving it"
    done
fi

[ "$fail" -eq 0 ] && echo "PLAN: $PLAN conformant (plan format v1)"
exit "$fail"
