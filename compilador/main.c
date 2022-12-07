#include <stdio.h>
#include <stdlib.h>
#include "lexico.h"

extern int yyparse();
extern FILE *yyin;
FILE *fich;

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        printf("Uso: %s fichero\n", argv[0]);
        exit(2);
    }

    if ((fich=fopen(argv[1],"r"))==NULL)
    {
        printf("***ERROR, no puedo abrir el fichero\n");
        exit(1);
    }

    yyin=fich;
    int i;
    yyparse();
    fclose(fich);
    return 0;
}
