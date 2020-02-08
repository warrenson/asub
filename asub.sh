# asub.sh
# source $0

# if not in internal run mode, prepare the job run
function asub {
    if [ "$1" == '--run' ]
    then
        __asub_run "$@"
    else
        # Generate jobs for array submission
        # DOCUMENTATION
        __usage()
        {
          echo "Usage: $0 stuff"
        }

        # OPTIONS
        local OPTIND # Must be local
        declare -A ASUB_VARS

        # DEFAULTS
        ASUB_VARS[VERBOSE]=0

        while getopts 'c:C:gG:hj:k:M:m:n:pP:q:R:vw:W:x:' opt
        do
            case $opt in
                #c:
                #C:
                #g
                #G:
                j) ASUB_VARS[JOB_NAME]="$OPTARG" ;;
                #k:
                #M:
                #m:
                n) ASUB_VARS[NCORES]="$OPTARG" ;;
                #p
                #P:
                #q:
                #R:
                #w:
                v) ASUB_VARS[VERBOSE]=$((ASUB_VARS[VERBOSE]+1)) ;;
                #W:
                #x:
                h|?) __usage && return 2 ;; esac
        done

        # GENERATE RANDOM JOBNAME?
        if [ ! ${ASUB_VARS[JOB_NAME]+_} ]
        then
            ASUB_VARS[JOB_NAME]="$(mktemp -u asub_XXXXXX)"
        fi

        # DEFINE OUTPUTS
        ASUB_VARS[JOB_CMD_FILE]="${ASUB_VARS[JOB_NAME]}.sh"
        ASUB_VARS[JOB_OUT_DIR]="${ASUB_VARS[JOB_NAME]}.out"
        ASUB_VARS[JOB_ERR_DIR]="${ASUB_VARS[JOB_NAME]}.err"

        # Be verbose?
        if [ ${ASUB_VARS[VERBOSE]} -gt 0 ]
        then
            for var in "${!ASUB_VARS[@]}"
            do
                echo "${var}: ${ASUB_VARS[$var]}" >&2
            done
        fi

        # WRITE INCOMING COMMANDS TO FILE
        ASUB_NJOBS=0
        test -f ${ASUB_VARS[JOB_CMD_FILE]} && rm $_

        while read -r LINE
        do
             echo "$LINE" >> ${ASUB_VARS[JOB_CMD_FILE]}
             ASUB_NJOBS=$((ASUB_NJOBS+1))
        done < <( grep -v '^[[:space:]]*$' ) # from /dev/stdin

        # CREATE OUTPUT LOG DIRS
        mkdir -p ${ASUB_VARS[JOB_OUT_DIR]}
        mkdir -p ${ASUB_VARS[JOB_ERR_DIR]}

        # GET JOB COMMAND
        unset JOB_CMD
        # select scheduler, first one found is used
        for scheduler in 'sbatch' 'bsub'
        do
            command -v "$scheduler" > /dev/null
            if [ $? -eq 0 ]
            then
                echo 
                JOB_CMD="$(__asub_${scheduler}_cmd)"
                echo -e "CMD:\n$JOB_CMD" >&2
                break
            fi
        done

    fi

    return 0
}
export -f asub

function __asub_bsub_cmd {
    # PREAMBLE
    echo "bsub << EOS"
    echo "#!/bin/bash"
    echo "#BSUB -J ${ASUB_VARS[JOB_NAME]}\"[1-${ASUB_NJOBS}]${ASUB_VARS[c]}\""
    echo "#BSUB -o ${ASUB_VARS[JOB_OUT_DIR]}/%I.out"
    echo "#BSUB -e ${ASUB_VARS[JOB_ERR_DIR]}/%I.err"
    echo

    # QUEUE?

    # RESOURCES?

    # DEPENDANCY?

    # ASUB RUN COMMAND
    echo "asub --run \$LSB_JOBINDEX ${ASUB_VARS[GROUP]} ${ASUB_VARS[JOB_CMD_FILE]}"

    # CLOSE JOB SCRIPT
    echo
    echo "EOS"
}
export -f __asub_bsub_cmd

function __asub_run {
    echo "$@"
    return 0
}
export -f __asub_run
