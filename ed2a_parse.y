%{
#include "ed2_misc.h"
#include "ed2a.h"
#include "ed2a_parse.h"
#include "ed2a_lex.h"
#include <stdio.h>
void ed2a_error (YYLTYPE *loc, yyscan_t lex_state, void (*fun) (struct ed2a_insn *insn, void *parm), void *parm, struct ed2a_file **res, char const *err) {
	fprintf (stderr, "%d.%d-%d.%d: %s\n", loc->first_line, loc->first_column, loc->last_line, loc->last_column, err);
}
%}

%locations
%define api.pure
%name-prefix "ed2a_"
%lex-param { yyscan_t lex_state }
%parse-param { yyscan_t lex_state }
%parse-param { void (*fun) (struct ed2a_insn *insn, void *parm) }
%parse-param { void *parm }
%parse-param { struct ed2a_file **res }

%union {
	uint64_t num;
	char *str;
	struct ed2a_expr *expr;
	struct ed2a_file *file;
	struct ed2a_insn *insn;
	struct ed2a_ipiece *ipiece;
	struct ed2a_iop *iop;
	struct ed2a_rvec *rvec;
	struct ed2a_swz *swz;
	struct ed2a_astr astr;
}

/* XXX: destructors */

%token <str> T_WORD
%token <str> T_HASHWORD
%token <str> T_WORDLB
%token <str> T_REG
%token <astr> T_STR
%token <num> T_NUM
%token T_ERR
%token T_UMINUS
%token T_PLUSPLUS
%token T_MINUSMINUS
%token T_PLUSEQ
%token T_MINUSEQ

%type <file> file
%type <insn> line
%type <insn> insn
%type <ipiece> ipiece
%type <ipiece> ipiecenp
%type <iop> iop
%type <iop> oexprt
%type <rvec> rvec
%type <str> mems
%type <expr> expr
%type <expr> exprt
%type <expr> expr4
%type <expr> expr5
%type <expr> expr6
%type <expr> expr7
%type <swz> swzspec
%type <swz> swzspecs

%destructor { ed2a_del_file($$); } <file>
%destructor { ed2a_del_insn($$); } <insn>
%destructor { ed2a_del_ipiece($$); } <ipiece>
%destructor { ed2a_del_iop($$); } <iop>
%destructor { ed2a_del_expr($$); } <expr>
%destructor { ed2a_del_rvec($$); } <rvec>
%destructor { ed2a_del_swz($$); } <swz>
%destructor { free($$); } <str>
%destructor { free($$.str); } <astr>

%%

start:	file				{ *res = $1; }
;

file:	file line			{ $$ = $1; if (!fun) { if ($2) ADDARRAY($$->insns, $2); else $$->broken = 1; } else { if ($2) fun($2, parm); } }
|	file '\n'			{ $$ = $1; }
|	/**/				{ if (!fun) $$ = calloc(sizeof *$$, 1); }
;

line:	insn ';'
|	insn '\n'
|	T_WORD ':'			{ $$ = ed2a_make_label_insn($1); }
|	error '\n'			{ $$ = 0; }
|	error ';'			{ $$ = 0; }
;

insn:	ipiece				{ $$ = calloc (sizeof *$$, 1); ADDARRAY($$->pieces, $1); }
|	insn '&' '\n' ipiece		{ $$ = $1; ADDARRAY($$->pieces, $4); }
|	insn '\n' '&' ipiece		{ $$ = $1; ADDARRAY($$->pieces, $4); }
|	insn '&' ipiece			{ $$ = $1; ADDARRAY($$->pieces, $3); }
;

ipiece:	ipiecenp
|	expr ipiece			{ $$ = $2; ADDARRAY($$->prefs, $1); }
;

ipiecenp:	T_WORD			{ $$ = calloc (sizeof *$$, 1); $$->name = $1; }
|	ipiecenp iop			{ $$ = $1; ADDARRAY($$->iops, $2); }
;

iop:	T_WORD iop			{ $$ = $2; ADDARRAY($$->mods, $1); }
|	oexprt
;

oexprt:	exprt				{ $$ = calloc (sizeof *$$, 1); ADDARRAY($$->exprs, $1); }
|	oexprt '|' exprt		{ $$ = $1; ADDARRAY($$->exprs, $3); }
;

exprt:	expr4
;

expr:	expr4
;

expr4:	expr4 '+' expr5			{ $$ = ed2a_make_expr_bi(ED2A_ET_PLUS, $1, $3); }
|	expr4 '-' expr5			{ $$ = ed2a_make_expr_bi(ED2A_ET_MINUS, $1, $3); }
|	expr5
;

expr5:	expr5 '*' expr6			{ $$ = ed2a_make_expr_bi(ED2A_ET_MUL, $1, $3); }
|	expr6
;

expr6:	T_UMINUS expr6			{ $$ = ed2a_make_expr_bi(ED2A_ET_UMINUS, $2, 0); }
|	expr7
;

expr7:	expr7 '.' swzspec		{ $$ = ed2a_make_expr_swz($1, $3); }
|	expr7 '.' '(' swzspecs ')'	{ $$ = ed2a_make_expr_swz($1, $4); }
|	'#'				{ $$ = ed2a_make_expr(ED2A_ET_DISCARD); }
|	'(' expr ')'			{ $$ = $2; }
|	'(' ipiecenp ')'		{ $$ = ed2a_make_expr_ipiece($2); }
|	mems expr ']'			{ $$ = ed2a_make_expr_mem(ED2A_ET_MEM, $1, $2, 0); }
|	mems expr T_PLUSPLUS expr ']'	{ $$ = ed2a_make_expr_mem(ED2A_ET_MEMPOSTI, $1, $2, $4); }
|	mems expr T_MINUSMINUS expr ']'	{ $$ = ed2a_make_expr_mem(ED2A_ET_MEMPOSTD, $1, $2, $4); }
|	mems expr T_PLUSEQ expr ']'	{ $$ = ed2a_make_expr_mem(ED2A_ET_MEMPREI, $1, $2, $4); }
|	mems expr T_MINUSEQ expr ']'	{ $$ = ed2a_make_expr_mem(ED2A_ET_MEMPRED, $1, $2, $4); }
|	T_HASHWORD			{ $$ = ed2a_make_expr_str(ED2A_ET_LABEL, $1); }
|	T_NUM				{ $$ = ed2a_make_expr_num($1); }
|	T_NUM ':' T_NUM			{ $$ = ed2a_make_expr_num2($1, $3); }
|	T_REG				{ $$ = ed2a_make_expr_str(ED2A_ET_REG, $1); }
|	T_REG ':' T_REG			{ $$ = ed2a_make_expr_reg2($1, $3); }
|	'{' rvec '}'			{ $$ = ed2a_make_expr_rvec($2); }
|	T_STR				{ $$ = ed2a_make_expr_str(ED2A_ET_STR, $1.str); $$->num = $1.len; }
;

rvec:	rvec T_REG			{ $$ = $1; ADDARRAY($$->elems, $2); }
|	rvec '#'			{ $$ = $1; ADDARRAY($$->elems, 0); }
|	/**/				{ $$ = calloc (sizeof *$$, 1); }
;

swzspecs:	swzspecs swzspec	{ $$ = ed2a_make_swz_cat($1, $2); if (!$$) YYERROR; }
|	/**/				{ $$ = ed2a_make_swz_empty(); }
;

swzspec:	T_WORD			{ $$ = ed2a_make_swz_str($1); if (!$$) YYERROR; }
|	T_NUM				{ $$ = ed2a_make_swz_num($1); }
;

mems:	'['				{ $$ = 0; }
|	T_WORDLB			{ $$ = $1; }
;


%%

struct ed2a_file *ed2a_read_file (FILE *file, void (*fun) (struct ed2a_insn *insn, void *parm), void *parm) {
	struct ed2a_file *res;
	yyscan_t lex_state;
	ed2a_lex_init(&lex_state);
	ed2a_set_in(file, lex_state);
	ed2a_parse(lex_state, fun, parm, &res);
	ed2a_lex_destroy(lex_state);
	return res;
}
