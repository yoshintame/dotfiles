function dnames-fn {
	for ID in `docker ps | awk '{print $1}' | grep -v 'CONTAINER'`
	do
    	docker inspect $ID | grep Name | head -1 | awk '{print $2}' | sed 's/,//g' | sed 's%/%%g' | sed 's/"//g'
	done
}

function dip-fn {
    echo "IP addresses of all named running containers"

    for DOC in `dnames-fn`
    do
        IP=`docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$DOC"`
        OUT+=$DOC'\t'$IP'\n'
    done
    echo -e $OUT | column -t
    unset OUT
}

function dex-fn {
	docker exec -it $1 ${2:-bash}
}

function dsr-fn {
	docker stop $1;docker rm $1
}

function drmid-fn {
    imgs=$(docker images -q -f dangling=true)
    [ ! -z "$imgs" ] && docker rmi "$imgs" || echo "no dangling images."
}

function drme-fn {
    docker rm $(docker ps --all -q -f status=exited)
}

function drma-fn {
    docker rm $(docker ps -a -q)
}

alias d="docker"
alias dc="docker compose"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcr="docker compose run" # docker compose run
alias dex=dex-fn # dex <container>: execute a bash shell inside the RUNNING <container>
alias di="docker inspect" # di <container> : docker inspect <container>
alias dim="docker images"
alias dip=dip-fn # IP addresses of all running containers
alias dl="docker logs -f" # dl <container> : docker logs -f <container>
alias dnames=dnames-fn # names of all running containers
alias dps="docker ps"
alias dpsa="docker ps -a"
alias drme=drme-fn
alias drma=drma-fn
alias drmid=drmid-fn # remove all dangling images
alias drun="docker run -it" # drun <image> : execute a bash shell in NEW container from <image>
alias dsp="docker system prune --all"
alias dsr=dsr-fn # dsr <container>: stop then remove <container>
