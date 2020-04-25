#! /bin/sh

awk '
BEGIN	{
	base_class_f = "CompilerBaseDefs.h"
	sub_class_f = "CompilerSubDefs.h"
	ops_f = "CompilerOpsDefs.h"
	ops_names_f = "CompilerOpsNamesDefs.h"
	ops_eval_f = "CompilerOpsEvalDefs.h"
	methods_f = "CompilerOpsMethodsDefs.h"
	exprsC1_f = "CompilerOpsExprsDefsC1.h"
	exprsC2_f = "CompilerOpsExprsDefsC2.h"
	exprsC3_f = "CompilerOpsExprsDefsC3.h"
	exprsV_f = "CompilerOpsExprsDefsV.h"

	prep(exprsC1_f)
	prep(exprsC2_f)
	prep(exprsC3_f)
	prep(exprsV_f)

	args["X"] = "()"
	args["O"] = "(OpaqueVals* v)"
	args["V"] = "(const NameExpr* n)"
	args["VV"] = "(const NameExpr* n1, const NameExpr* n2)"
	args["VVV"] = "(const NameExpr* n1, const NameExpr* n2, const NameExpr* n3)"
	args["VVVV"] = "(const NameExpr* n1, const NameExpr* n2, const NameExpr* n3, const NameExpr* n4)"
	args["C"] = "(const ConstExpr* c)"
	args["VC"] = "(const NameExpr* n, ConstExpr* c)"
	args["VVC"] = "(const NameExpr* n1, const NameExpr* n2, ConstExpr* c)"
	args["VCV"] = "(const NameExpr* n1, ConstExpr* c, const NameExpr* n2)"

	args2["X"] = ""
	args2["O"] = "reg"
	args2["V"] = "n"
	args2["VV"] = "n1, n2"
	args2["VVV"] = "n1, n2, n3"
	args2["VVVV"] = "n1, n2, n3, n4"
	args2["C"] = "c"
	args2["VC"] = "n, c"
	args2["VVC"] = "n1, n2, c"
	args2["VCV"] = "n1, c, n2"

	exprC1["VC"] = "lhs, r1->AsConstExpr()";
	exprC1["VCV"] = "lhs, r1->AsConstExpr(), r2->AsNameExpr()"

	exprC2["VVC"] = "lhs, r1->AsNameExpr(), r2->AsConstExpr()"
	exprC2["VVCC"] = "lhs, r1->AsNameExpr(), r2->AsConstExpr(), r3->AsConstExpr()"
	exprC2["VVCV"] = "lhs, r1->AsNameExpr(), r2->AsConstExpr(), r3->AsNameExpr()"

	exprC3["VVVC"] = "lhs, r1->AsNameExpr(), r2->AsNameExpr(), r3->AsConstExpr()"

	exprV["X"] = ""
	exprV["V"] = "lhs"
	exprV["VV"] = "lhs, r1->AsNameExpr()"
	exprV["VVV"] = "lhs, r1->AsNameExpr(), r2->AsNameExpr()"
	exprV["VVVV"] = "lhs, r1->AsNameExpr(), r2->AsNameExpr(), r3->AsNameExpr()"

	accessors["I"] = ".int_val"
	accessors["U"] = ".uint_val"
	accessors["D"] = ".double_val"
	}

$1 == "op"	{ dump_op(); op = $2; next }
$1 == "expr-op"	{ dump_op(); op = $2; expr_op = 1; next }
$1 == "unary-op"	{ dump_op(); op = $2; unary_op = 1; next }
$1 == "unary-expr-op"	{ dump_op(); op = $2; expr_op = 1; unary_op = 1; next }
$1 == "internal-op"	{ dump_op(); op = $2; internal_op = 1; next }

$1 == "type"	{ type = $2; next }
$1 == "op-type"	{ operand_type = $2; next }
$1 == "opaque"	{ opaque = 1; next }
$1 == "eval"	{
		new_eval = all_but_first()
		if ( operand_type == "" )
			new_eval = new_eval ";"

		if ( eval )
			{
			if ( operand_type )
				gripe("cannot intermingle op-type and multi-line evals")

			eval = eval "\n\t\t" new_eval

			# The following variables are just to enable
			# us to produce tidy-looking switch blocks.
			multi_eval = "\n\t\t"
			eval_blank = ""
			}
		else
			{
			eval = new_eval
			eval_blank = " "
			}
		next
		}

$1 == "method-pre"	{ method_pre = all_but_first(); next }

/^#/		{ next }
/^[ \t]*$/	{ next }

	{ gripe("unrecognized compiler template line: " $0) }

END	{
	dump_op()

	finish(exprsC1_f, "C1")
	finish(exprsC2_f, "C2")
	finish(exprsC3_f, "C3")
	finish(exprsV_f, "V")
	}

function all_but_first()
	{
	all = ""
	for ( i = 2; i <= NF; ++i )
		{
		if ( i > 2 )
			all = all " "

		all = all $i
		}

	return all
	}

function dump_op()
	{
	if ( ! op )
		return

	if ( unary_op )
		{
		build_op(op, "VV", expand_eval(eval, expr_op, operand_type, 1))

		# Note, for most operators the constant version would have
		# already been folded, but for some like AppendTo, they
		# cannot, so we account for that possibility here.
		build_op(op, "VC", expand_eval(eval, expr_op, operand_type, 0))
		}
	else
		build_op(op, type, eval)

	clear_vars()
	}

function expand_eval(e, is_expr_op, otype, is_var)
	{
	accessor = laccessor = raccessor = ""
	if ( otype )
		{
		if ( ! (otype in accessors) )
			gripe("bad operand_type: " otype)

		accessor = accessors[otype]
		laccessor = accessor
		raccessor = accessor ";"
		}

	rep = (is_var ? "frame[s.v2]" : "s.c")
	e_copy = e
	gsub(/\$1/, rep, e_copy)

	if ( is_expr_op )
		return "frame[s.v1]" laccessor " = " e_copy raccessor
	else
		return e_copy accessor
	}

function build_op(op, type, eval)
	{
	if ( ! (type in args) )
		gripe("bad type " type " for " op)

	orig_op = op
	gsub(/-/, "_", op)
	upper_op = toupper(op)
	full_op = "OP_" upper_op "_" type
	op_type = op type

	if ( ! internal_op )
		{
		print ("\tvirtual const CompiledStmt " op_type args[type] " = 0;") >base_class_f
		print ("\tconst CompiledStmt " op_type args[type] " override;") >sub_class_f
		}

	print ("\t" full_op ",") >ops_f
	print ("\tcase " full_op ":\treturn \"" tolower(orig_op) "-" type "\";") >ops_names_f
	print ("\tcase " full_op ":\n\t\t{ " multi_eval eval multi_eval eval_blank "}" multi_eval eval_blank "break;\n") >ops_eval_f

	if ( ! internal_op )
		{
		print ("const CompiledStmt AbstractMachine::" op_type args[type]) >methods_f

		print ("\t{") >methods_f
		if ( method_pre )
			print ("\t" method_pre ";") >methods_f
		if ( type == "O" )
			print ("\treturn AddStmt(AbstractStmt(" full_op ", reg));") >methods_f
		else if ( args2[type] != "" )
			print ("\treturn AddStmt(GenStmt(this, " full_op ", " args2[type] "));") >methods_f
		else
			print ("\treturn AddStmt(GenStmt(this, " full_op"));") >methods_f

		print ("\t}\n") >methods_f
		}

	if ( expr_op )
		{
		if ( type == "C" )
			gripe("bad type " type " for expr " op)

		expr_case = "EXPR_" upper_op

		if ( type in exprC1 )
			{
			eargs = exprC1[type]
			f = exprsC1_f
			}

		else if ( type in exprC2 )
			{
			eargs = exprC2[type]
			f = exprsC2_f
			}

		else if ( type in exprC3 )
			{
			eargs = exprC3[type]
			f = exprsC3_f
			}

		else if ( type in exprV )
			{
			eargs = exprV[type]
			f = exprsV_f
			}

		else
			gripe("bad type " type " for expr " op)

		print ("\tcase " expr_case ":\treturn c->" op_type "(" eargs ");") >f
		}
	}

function clear_vars()
	{
	opaque = type = eval = multi_eval = eval_blank = method_pre = ""
	internal_op = unary_op = expr_op = op = ""
	operand_type = ""
	}

function prep(f)
	{
	print ("\t{") >f
	print ("\tswitch ( rhs->Tag() ) {") >f
	}

function finish(f, which)
	{
	print ("\tdefault:") >f
	print ("\t\treporter->InternalError(\"inconsistency in " which " AssignExpr::Compile\");") >f
	print ("\t}\t}") >f
	}

function gripe(msg)
	{
	print "error at input line", NR ":", msg
	exit(1)
	}
' $*