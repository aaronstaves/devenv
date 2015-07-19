export PATH="$PATH"
export PERL5LIB="$PERL5LIB"

pathadd() {
    case ":${PATH:=$1}:" in
        *:$1:*)  ;;
        *) PATH="$PATH:$1"  ;;
    esac
}
perladd() {
    case ":${PERL5LIB:=$1}:" in
        *:$1:*)  ;;
        *) PERL5LIB="$PERL5LIB:$1"  ;;
    esac
}

perladd "$PWD/lib"
perladd "$PWD/local/lib/perl5"

pathadd "$PWD/bin"
pathadd "$PWD/local/bin"
