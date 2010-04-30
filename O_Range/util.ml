open Cabs
open Frontc
open Cprint
open Cvariables
open Coutput
open Rename
open Printf
let vDEBUG = ref false

let (alreadyAffectedGlobales: string list ref) = ref []

let (listEnumId: string list ref) = ref []


(* ABSTRATC STORE TYPE*)
type expVA = EXP  of expression |	MULTIPLE
type abstractStore =
		ASSIGN_SIMPLE of string  * expVA
	|	ASSIGN_DOUBLE of string * expVA * expVA
	|   ASSIGN_MEM of string * expVA * expVA 


let new_assign_simple id exp  = ASSIGN_SIMPLE(id, exp)
let new_assign_double id exp1 exp2  = ASSIGN_DOUBLE(id, exp1, exp2)
let new_assign_mem id exp1 exp2  = ASSIGN_MEM (id, exp1, exp2)
let (alreadyEvalFunctionAS: (string * abstractStore list)list ref) = ref []


(* ABSTRATC STORE TYPE END*)
(*Amarguellat instruction *)
let isIntoSwithch = ref false
type corpsInfo = 
      CORPS of inst
     | ABSSTORE of abstractStore list
  and    
  inst =
	  VAR of string * expVA	* string list	* string list (*assign after, used after*)
	| MEMASSIGN of string * expVA * expVA * string list	* string list
	| TAB of string * expVA * expVA* string list	* string list
	| IFV of expVA * inst 			
	| IFVF of expVA * inst * inst			  
	| BEGIN of inst list 
	| FORV of int*string * expVA * expVA * expVA * expVA *inst 	(*derniere expression nb it*)* string list(*ptr changed into loop*)
	| APPEL of int*inst*(* inst*) string * inst*corpsInfo *string*string* string list (* used after*)




	

(* il  faudra ajouter les struct *)
let new_instVar id exp  =
		 VAR(id, (if !isIntoSwithch = false then exp else EXP(NOTHING)), [],[])
let new_instMem id exp1 exp2   = MEMASSIGN(id, exp1, (if !isIntoSwithch = false then exp2  else EXP(NOTHING)),[],[])
let new_instTab id exp1 exp2  = TAB(id, exp1,( if !isIntoSwithch = false then exp2  else EXP(NOTHING)),[],[])
let new_instIFVF exp inst1 inst2  = IFVF(exp, inst1, inst2)
let new_instIFV exp inst1   = IFV(exp, inst1)
let new_instFOR num id exp1 exp2 exp3 nbIt inst c = FORV(num,id, exp1, exp2, exp3, nbIt, inst,c)
let new_instBEGIN listeInst  = BEGIN(listeInst)
let new_instAPPEL num instAffectIn nom instAffectSortie corps s = APPEL(num, instAffectIn, nom, instAffectSortie, (CORPS corps), s, "",[])
let new_instAPPELCOMP num instAffectIn nom instAffectSortie absStore s = APPEL(num, instAffectIn, nom, instAffectSortie, (ABSSTORE absStore), s, "",[])

let (alreadyDefFunction: (string * inst list)list ref) = ref []
let (alreadyDefFunctionForPtr: (string * inst list)list ref) = ref []


let add_list_body   v =  
  alreadyDefFunction := v :: (!alreadyDefFunction)

let get_fct_body   n =  
 
  if List.mem_assoc n !alreadyDefFunction then List.assoc n !alreadyDefFunction else []


let add_list_bodyForPtr   v =  
  alreadyDefFunctionForPtr := v :: (!alreadyDefFunctionForPtr)

let get_fct_bodyForPtr   n =  
 
  if List.mem_assoc n !alreadyDefFunctionForPtr then List.assoc n !alreadyDefFunctionForPtr else []

let setalreadyDefFunction mes =
alreadyDefFunction:=!alreadyDefFunctionForPtr;
alreadyDefFunctionForPtr:=[]


(*Amarguellat instruction END *)

 	type arraySize = NOSIZE | SARRAY of int |MSARRAY of int list


	let listAssosArrayIDsize  =  ref [(" ", NOSIZE)]
	let existAssosArrayIDsize name  = (List.mem_assoc name !listAssosArrayIDsize)
	let setAssosArrayIDsize name size = 
		if existAssosArrayIDsize name = false then listAssosArrayIDsize := List.append   [(name, size)]   !listAssosArrayIDsize 	
	let getAssosArrayIDsize name  = if existAssosArrayIDsize name then (List.assoc name !listAssosArrayIDsize) else NOSIZE

	let listAssosTypeDefArrayIDsize  = ref [(" ", NOSIZE)]
	let existAssosTypeDefArrayIDsize  name  = (List.mem_assoc name !listAssosTypeDefArrayIDsize)
	let setAssosTypeDefArrayIDsize  name size = 
		if existAssosTypeDefArrayIDsize name = false then listAssosTypeDefArrayIDsize := List.append   [(name, size)]   !listAssosTypeDefArrayIDsize 	
	let getAssosTypeDefArrayIDsize name  = if existAssosTypeDefArrayIDsize name then (List.assoc name !listAssosTypeDefArrayIDsize) else NOSIZE
	let  (listAssosTypeDefArrayIDbaseType: (string *base_type )list ref)= ref []
	let existAssosTypeDefArrayIDbaseType  name  = (List.mem_assoc name !listAssosTypeDefArrayIDbaseType)
	let setAssosTypeDefArrayIDbaseType   name t = 
		if existAssosTypeDefArrayIDbaseType name = false then listAssosTypeDefArrayIDbaseType := List.append   [(name, t)]   !listAssosTypeDefArrayIDbaseType 	
	let getAssosTypeDefArrayIDbaseType name  =  List.assoc name !listAssosTypeDefArrayIDbaseType 



	


	let (listOfArrayType: (string *base_type )list ref)= ref [](*[(" ", NO_TYPE)]*)


	let existAssosArrayType   name  = (List.mem_assoc name !listOfArrayType)
	let setAssosArrayType   name typ = 
		if existAssosArrayType name = false then listOfArrayType := List.append   [(name, typ)]   !listOfArrayType 	

	let getAssosAssosArrayType name  = if existAssosArrayType name then (List.assoc name !listOfArrayType) else NO_TYPE


	let rec nbItems l  = if l = [] then 0 else nbItems (List.tl l) +1 
		

	let print_AssosArrayIDsize l=
		List.iter (fun (a, b) -> Printf.printf "%s  " a; 
					match b with 
						 NOSIZE -> Printf.printf "NOSIZE\n"
						| SARRAY (v) -> Printf.printf "SINGLE ARRAY %d\n" v
						| MSARRAY (l) ->  Printf.printf "MULTI ARRAY ";List.iter(fun dim-> Printf.printf "%d  " dim; )l ;Printf.printf "\n"
				   ) l 	

type newBaseType =
	FLOAT_TYPE (*float values*)
	|INT_TYPE
(*	| ENUM_TYPE of string*)
	| UNION_TYPE  of string
	| TYPEDEF_NAME of string
	|  STRUCT_TYPE of string 



type decType =
STRUCTORUNION of (string*newBaseType*base_type) list
| TYPEDEFTYPE of newBaseType*base_type

let newDecTypeSTRUCTORUNION l = STRUCTORUNION(l)
let newDecTypeTYPEDEFTYPE n t = TYPEDEFTYPE(n ,t )

let listAssosIdTypeTypeDec = ref []
 
let listAssocIdType  = ref [] (* assos id var type base *)



let rec getBaseType t =
match t with
	FLOAT_TYPE |INT_TYPE -> t 
	| UNION_TYPE s -> t
	| TYPEDEF_NAME s->  
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  TYPEDEFTYPE (typ,_) -> getBaseType typ  | _->t
		 end
		 else t
	|  STRUCT_TYPE s ->  t

(*let getAllSTructOrUnionType liste =
List.map*)

let rec printfBaseType t=
match t with
	FLOAT_TYPE -> Printf.printf " flottant "
	|INT_TYPE -> Printf.printf " integer "
	| UNION_TYPE s ->  Printf.printf " union of %s" s
	| TYPEDEF_NAME s->  Printf.printf " type of %s" s;
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  TYPEDEFTYPE (typ,_) -> printfBaseType typ  | _->Printf.printf " inconnu TYPEDEFTYPE"
		 end
	|  STRUCT_TYPE s ->  Printf.printf " struct of %s" s;
		if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  
				STRUCTORUNION (l) -> List.iter (fun(n,t,_)-> Printf.printf " champ %s type\n" n ; printfBaseType t; new_line() )l  
				| TYPEDEFTYPE (n,_)->Printf.printf " inconnu \n ";printfBaseType n
		 end


let rec mayByAffect  t  tyf  =
let nt = getBaseType t in (*printfBaseType t;*)
match tyf with
	FLOAT_TYPE   ->
			(
				match nt with
					INT_TYPE -> false
					| _ -> true
			)
	|INT_TYPE -> 
			(
				match nt with
					FLOAT_TYPE -> false
					| _ -> true
			)


	|  STRUCT_TYPE s | UNION_TYPE s | TYPEDEF_NAME s->  
			(
				match nt with
					INT_TYPE -> false
					| FLOAT_TYPE -> false
					| _ -> true
			)
		 

let mayBeAssignVar listeOfVar ty =
(*Printf.printf "mayBeAssignVar"; printfBaseType ty;*)
List.filter (fun v ->
		if List.mem_assoc v !listAssocIdType then
		 ( 
			let itsType = (List.assoc v !listAssocIdType) in (*Printf.printf "%s" v;*)
			mayByAffect  itsType ty
		 )
		else true
		 
)listeOfVar



let rec isStructAndGetIt t =
match t with
	FLOAT_TYPE |INT_TYPE ->  (false,t) 
	| UNION_TYPE s ->  (false,t)
	| TYPEDEF_NAME s-> 
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin 
			match  (List.assoc s !listAssosIdTypeTypeDec)  with
					  TYPEDEFTYPE (typ,_) ->(*Printf.printf "isStructAndGetItchanged"; *) isStructAndGetIt typ
					|(* _->(false,t)*) STRUCTORUNION _ -> (true, t) (* no union type for the moment LAST REVOIR*)
		 end
		 else (Printf.printf "TYPEDEF_NAME\n"; (false, t))
	|  STRUCT_TYPE s ->   (true,t)




let rec getInitVarFromStruct (exp : expression)   =
	 match exp with
		 VARIABLE name ->  [name] 
		| INDEX (e, _)  -> getInitVarFromStruct e 
		| MEMBEROF (e, c)  | MEMBEROFPTR (e, c) -> List.append (getInitVarFromStruct e) [c]
		| UNARY (op, e) ->
					(match op with 
							ADDROF ->
								(*Printf.printf "getInitVarFromStruct &assign\n";*)
								getInitVarFromStruct e 
							|_->(*Printf.printf "not &assign\n";*)[])
		| _-> []


let rec  equalList lid1 lid2 =
if lid1 = [] && lid2  = [] then true
else if lid1 = [] || lid2 = [] then false
	 else
	 begin
		( List.hd lid1  = List.hd  lid2) && (equalList (List.tl lid1) (List.tl lid2))
	 end


(*	let nee = consCommaExp (VARIABLE(id)) btype [id] lid ne  in*)
let rec consCommaExp front t champlist champlistLookingFor exp  withindex index=
match t with
	FLOAT_TYPE |INT_TYPE  -> 
				if champlistLookingFor = [] then (*front VARIABLE ("NOINIT")*)front
				else
				begin
					let ncl = getInitVarFromStruct front in 
					if equalList ncl champlistLookingFor then 
						if withindex then 
						begin
							
							exp
						end
						else	exp	
					else (*front*)VARIABLE ("--NOINIT--")
				end
	|UNION_TYPE s| TYPEDEF_NAME s->  
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with 
				 TYPEDEFTYPE (typ,_) -> consCommaExp front typ champlist champlistLookingFor exp withindex index | _->(*front VARIABLE ("NOINIT")*) front
		 end
		else (*front VARIABLE ("NOINIT")*)front
	|  STRUCT_TYPE s ->  
		if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  
				STRUCTORUNION (l) -> 
					
							CONSTANT(	CONST_COMPOUND(
									List.map (
									fun(n,t,_)->  
											 
										  consCommaExp ( MEMBEROF (front, n)) t champlist champlistLookingFor exp   withindex index
									)l  ))
						
				| _->(*frontVARIABLE ("NOINIT")*)front
		 end
		else (*front VARIABLE ("NOINIT")*)front

let rec getconsCommaExp  t  champlistLookingFor lexp =

if champlistLookingFor = [] || lexp = []  then (NOTHING) else 
match t with
	FLOAT_TYPE |INT_TYPE  -> (NOTHING)
	|UNION_TYPE s| TYPEDEF_NAME s->  
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec) with  
				TYPEDEFTYPE (typ,_) -> 
										getconsCommaExp  typ  champlistLookingFor lexp 
				| _->(NOTHING)
		 end
		else (NOTHING)
	|  STRUCT_TYPE s ->  
	 
		if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  
			STRUCTORUNION (l) -> 
				if champlistLookingFor = [] || lexp = [] || l = [] then (NOTHING)
				else
				begin	
					let (champ,suitec,expChamp,suiteexpc) = (List.hd champlistLookingFor,List.tl champlistLookingFor,  List.hd lexp,  List.tl lexp) in
					let ((n,typ,_),suitedec) = (List.hd l,List.tl l) in
						(*Printf.printf "champ=%s, n %s\n"champ n;*)
					if n = champ then
						if  suitec = [] then begin  (*print_expression expChamp 0; new_line();  *)expChamp end(*trouve*)
						else getconsCommaExp  typ  suitec suiteexpc(*dans sous champs*)
					else getNextChamp  champlistLookingFor  suiteexpc suitedec (*dans autre champs*)
				end
				
			| TYPEDEFTYPE (n,_)->(Printf.printf "not membrer \n"; NOTHING)
		 end
		else (Printf.printf "not def struct\n"; NOTHING)

and getNextChamp lchamps  lexp ldec =
if lchamps = [] || lexp = [] || ldec = [] then (NOTHING)
else
begin	
	let (champ,suitec,expChamp,suiteexpc) = (List.hd lchamps,List.tl lchamps, List.hd lexp,  List.tl lexp) in
	let ((n,typ,_),suitedec) = (List.hd ldec,List.tl ldec) in
(*Printf.printf "getNextChamp champ=%s, n %s\n"champ n;*)
	if n = champ then
						if  suitec = [] then ( (* print_expression expChamp 0; new_line(); *) expChamp (*trouve*))
						else getconsCommaExp  typ  suitec suiteexpc(*dans sous champs*)
	else getNextChamp  lchamps  suiteexpc suitedec (*dans autre champs*)
end

let rec printfBaseType t=
match t with
	FLOAT_TYPE -> Printf.printf " flottant "
	|INT_TYPE -> Printf.printf " integer "
	| UNION_TYPE s ->  Printf.printf " union of %s" s
	| TYPEDEF_NAME s->  Printf.printf " type of %s" s;
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  TYPEDEFTYPE (typ,_) -> printfBaseType typ  | _->Printf.printf " inconnu TYPEDEFTYPE"
		 end
	|  STRUCT_TYPE s ->  Printf.printf " struct of %s" s;
		if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  
				STRUCTORUNION (l) -> List.iter (fun(n,t,_)-> Printf.printf " champ %s type\n" n ; printfBaseType t; new_line() )l  
				| TYPEDEFTYPE (n,_)->Printf.printf " inconnu \n ";printfBaseType n
		 end

let rec printfBaseTypeRestrict t=
match t with
	FLOAT_TYPE -> Printf.printf " flottant "
	|INT_TYPE -> Printf.printf " integer "
	| UNION_TYPE s ->  Printf.printf " union of %s" s
	| TYPEDEF_NAME s->  Printf.printf " type of %s" s;
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  TYPEDEFTYPE (typ,_) -> printfBaseTypeRestrict typ  | _->Printf.printf " inconnu TYPEDEFTYPE"
		 end
	|  STRUCT_TYPE s ->  Printf.printf " struct of %s" s
		



let (listeAssosPtrNameType: (string *newBaseType )list ref)=  ref []


	

	let setAssosPtrNameType  name t =if (List.mem_assoc name !listeAssosPtrNameType)= false then  listeAssosPtrNameType := List.append   [(name, t)]   !listeAssosPtrNameType 	
	let existAssosPtrNameType  name  = (List.mem_assoc name !listeAssosPtrNameType)
	let getAssosPtrNameType name  = (List.assoc name !listeAssosPtrNameType)
 

(* fonction de recherche booleenne *)
	let rec estProto typ =

		match typ with
		  PROTO (_, _, _) | OLD_PROTO (_, _, _) ->	true
		| GNU_TYPE (_, typ) ->estProto typ
		| TYPE_LINE (_, _, _typ) -> estProto typ
		| _ -> false
	
	let rec estPtrOuTableau typ  =
	  match typ with
	  PTR _| RESTRICT_PTR _ | ARRAY (_, _) -> true
	| CONST typ -> estPtrOuTableau typ 
	| VOLATILE typ -> estPtrOuTableau typ 
	| GNU_TYPE (_, typ) ->estPtrOuTableau typ 
	| NAMED_TYPE id ->    false  
	| _ -> false

	let rec estPtrOuTableauAux typ teps =
		let rep = estPtrOuTableau typ    in
				 if rep = false then
					let baseType = match  teps with TYPEDEF_NAME(id) ->   id |_-> "" in
		 			if baseType != "" && List.mem_assoc baseType !listAssosIdTypeTypeDec then 
					begin
							(match  (List.assoc baseType !listAssosIdTypeTypeDec) with  
							TYPEDEFTYPE (_,ttt) -> 
								let nr = estPtrOuTableau ttt  in
								(nr  )
							| _->  (false)
							)
					  
					end
					else (false)
				else (rep)


	let rec isPtrType typ   =
 
	  match typ with
	  PTR _| RESTRICT_PTR _ -> true
	| CONST typ -> isPtrType typ  
	| VOLATILE typ -> isPtrType typ  
	| GNU_TYPE (_, typ) ->isPtrType typ  
	| ARRAY (typ, _) -> isPtrType typ  
	| NAMED_TYPE id -> 
				 
					(*let baseType = match  teps  with TYPEDEF_NAME(id) ->   id |_-> "" in
 		 			if List.mem_assoc baseType !listAssosIdTypeTypeDec then 
					begin
							(match  (List.assoc baseType !listAssosIdTypeTypeDec) with  
							TYPEDEFTYPE (_,ttt) -> isPtrType ttt teps
							| _-> false )
					  
					end
					else  *) false  
			 

		(* if List.mem_assoc id !setAssosIDTYPEINIT then  isPtrType (List.assoc id !setAssosIDTYPEINIT)else false *)
	| _ -> (*Printf.printf "isPtrType default\n";*)false


	let rec estPtrAux typ teps =
		let rep = isPtrType typ    in
				 if rep = false then
					let baseType = match  teps with TYPEDEF_NAME(id) ->   id |_-> "" in
		 			if baseType != "" && List.mem_assoc baseType !listAssosIdTypeTypeDec then 
					begin
							(match  (List.assoc baseType !listAssosIdTypeTypeDec) with  
							TYPEDEFTYPE (_,ttt) -> 
								let nr = isPtrType ttt  in
								(nr  )
							| _->  (false)
							)
					  
					end
					else (false)
				else (rep)




let rec getArrayNameOfexp exp =
	match exp with
		  UNARY (op, e) ->
			let (tab1,lidx1, e1) =getArrayNameOfexp e in
			(match op with
			  MEMOF | ADDROF -> (tab1,lidx1,  UNARY (op,e1))
			|_->(tab1,lidx1, e1))

		| BINARY (_, exp1, exp2) ->
			let (tab1,lidx1, e1) = getArrayNameOfexp exp1 in
			if tab1 = "" then  getArrayNameOfexp exp2  
			else (tab1,lidx1, e1)
		| CAST (typ, e) -> getArrayNameOfexp e 
		| VARIABLE name -> (name, [], exp)
		| INDEX (exp1, idx) ->let (tab,lidx) = analyseArray exp []  in (tab,lidx, exp)
		|_ ->("", [], NOTHING)

and analyseArray exp lidx =
	match exp with 
		VARIABLE v -> (v , lidx)
		| INDEX (e, i) ->  analyseArray e (List.append [i] lidx) 
		| _ -> (* actuellement  non traitée *)("", lidx)

and analyseArrayIntostruct exp lidx =
	match exp with 
		VARIABLE v -> (exp , lidx)
		| INDEX (e, i) ->  analyseArrayIntostruct e (List.append [i] lidx) 
		| MEMBEROF (e , t) 			
		| MEMBEROFPTR (e , t)  -> (* actuellement  non traitée *)( exp ,lidx) 
		| _ -> (* actuellement  non traitée *)(NOTHING, lidx)




let  isArrayOrPtr var  =
 existAssosArrayIDsize var || List.mem_assoc var !listeAssosPtrNameType 

(* UTIL GETFUNCTION*)
let rec rechercheAffectVDsListeAS v (*index*) l =
(*Printf.printf "recherche %s dans liste :\n" v;afficherListeAS l;new_line ();Printf.printf "fin s liste :\n" ;*)
if l = [] then EXP(NOTHING)
else 
let a = List.hd l in
let suite = List.tl l in
	match a with
		ASSIGN_SIMPLE (s, e) 	 -> 	if s = v then e else rechercheAffectVDsListeAS v (*index*) suite
	|	ASSIGN_DOUBLE (s,e1, e2) -> 	
			if s = v (*and il faut évaluer les 2 expression index = e1*) then 
			begin
				if !vDEBUG then begin	Printf.printf "tableau avec index à terminer\n";(* afficherAS a *) end; 
				e2
			end
			else  rechercheAffectVDsListeAS v (*index*) suite
	| ASSIGN_MEM (s, e1, e2)	-> 
			if s = v (*and il faut évaluer les 2 expression index = e1*) then 
			begin
				if !vDEBUG then begin	Printf.printf "tableau avec index à terminer\n";(* afficherAS a *) end; 
				e2
			end
			else  rechercheAffectVDsListeAS v (*index*) suite


let rec getAllVARAssign   l =
(*Printf.printf "recherche %s dans liste :\n" v;afficherListeAS l;new_line ();Printf.printf "fin s liste :\n" ;*)
if l = [] then []
else 
let a = List.hd l in
let suite = List.tl l in
	match a with
		ASSIGN_SIMPLE (s, _) 	 -> 	s::getAllVARAssign suite
	|	ASSIGN_DOUBLE (s,_, _) 
	| ASSIGN_MEM (s, _, _)	-> s::getAllVARAssign suite






let (callsListEvalAssignVar:  (string *  (string list*  string list))   list ref)= ref []


let rec assignVar assignList  =(* return  assign  list*)
if assignList = [] then []
else
begin
	let (assign, next) = (List.hd assignList, assignVar (List.tl assignList)) in
 	let
		firstAs = match assign with
					VAR ( id, exp,_,_)  ->	
					if List.mem_assoc id !listeAssosPtrNameType   then  
						(match exp with
							EXP(CONSTANT(	CONST_COMPOUND(_)))-> ["*"^id] 
							 
						(* if a field of struct is assigned it is either a conmpoud either multiple not inportant*)
							|_-> [id]  )

				 	else [id]
					| TAB ( id, _, _,_,_)   |  MEMASSIGN ( id, _, _,_,_)->   
						let fid = 	if  String.length id > 1 then 
								if (String.sub id  0 1)="*" then  String.sub id 1 ((String.length id)-1) else id
							else id  in 
						if List.mem_assoc fid !listeAssosPtrNameType   then   ["*"^fid]  else  [id]  
					| IFVF ( _, i1, i2) 		-> 	union  (assignVar [i1])    (assignVar [i2] )	
					| IFV ( _, i1) 		-> 	assignVar [i1]
					| BEGIN (liste)		->  assignVar liste 
					| FORV (a, b, c, d, e,f, i,_) ->assignVar [i]  			
					| APPEL (num, e, nom, s, CORPS c,v,r,_) -> 
						let listVar = if List.mem_assoc nom !callsListEvalAssignVar then  (let (la,_) = List.assoc nom !callsListEvalAssignVar in la)  else assignVar [c] in
						let globalPtr = List.filter(fun x->   List.mem x !alreadyAffectedGlobales) listVar  in
						let sorties = (match s with BEGIN(sss)-> sss |_->[]) in


						let ass = 
							List.map 
											( fun sortie -> 
												(match sortie with 
													VAR (id, _,_,_) 
													| TAB (id, _, _,_,_) 
													|MEMASSIGN (id, _,_,_,_)->
														let fid = 	if  String.length id > 1 then 
														if (String.sub id  0 1)="*" then  String.sub id 1 ((String.length id)-1) else id
														else id  in 

															if List.mem_assoc fid !listeAssosPtrNameType   then  "*"^fid else fid
													|_->"")
											)sorties	in

						union globalPtr ass

					| APPEL (num, e, nom, s, ABSSTORE a,v,r,_) ->
						  let globalPtr = List.filter(fun x->   List.mem x !alreadyAffectedGlobales) (getAllVARAssign   a)  in
						  let sorties = (match s with BEGIN(sss)-> sss |_->[]) in

						  let ass =  
							List.map 
											( fun sortie -> 
												(match sortie with 
													VAR (id, _,_,_) 
													| TAB (id, _, _,_,_) 
													|MEMASSIGN (id, _,_,_,_)->
														let fid = 	if  String.length id > 1 then 
														if (String.sub id  0 1)="*" then  String.sub id 1 ((String.length id)-1) else id
														else id  in 

															if List.mem_assoc fid !listeAssosPtrNameType   then  "*"^fid else fid
													|_->"")
											)sorties	in


							union globalPtr ass in
	union firstAs next
end
(* CASTING FUNCTION*)	

let  expVaToExp exp = match exp with EXP(e) ->e| _->NOTHING
(*end*)

let rec getAllVARAssignAndUsed   l =
(*Printf.printf "recherche %s dans liste :\n" v;afficherListeAS l;new_line ();Printf.printf "fin s liste :\n" ;*)
if l = [] then ([],[])
else 
let a = List.hd l in
let suite = List.tl l in
	match a with
		ASSIGN_SIMPLE (s, e) 	 -> 	let (a,u) = getAllVARAssignAndUsed suite in 	(s::a, union  (listeDesVarsDeExpSeules   (expVaToExp e))   	u)
	|	ASSIGN_DOUBLE (id,i, e) 
	| 	ASSIGN_MEM (id,i, e) -> let (a,u) = getAllVARAssignAndUsed suite in 
										(id::a, union
												(union  (listeDesVarsDeExpSeules   (expVaToExp e)) (listeDesVarsDeExpSeules   (expVaToExp i)))
												u)




let rec assignVarAndUsed assignList  =(* return  assign  list*)
if assignList = [] then ([],[])
else
begin
	let (next, nu)= assignVarAndUsed (List.tl assignList) in
	let assign = List.hd assignList in
 	let
		(firstAs, firstUsed) = match assign with
					VAR ( id, exp,_,_)  ->	
					let assigned =
						if List.mem_assoc id !listeAssosPtrNameType   then  
							(match exp with
								EXP(CONSTANT(	CONST_COMPOUND(_)))-> ["*"^id] 
								 
							(* if a field of struct is assigned it is either a conmpoud either multiple not inportant*)
								|_-> [id]  )

					 	else [id] in
						(assigned, listeDesVarsDeExpSeules   (expVaToExp exp) )
					| TAB ( id, i, e,_,_)   |  MEMASSIGN ( id, i, e,_,_)->   
						let assigned =
							let fid = 	if  String.length id > 1 then 
									if (String.sub id  0 1)="*" then  String.sub id 1 ((String.length id)-1) else id
								else id  in 
							if List.mem_assoc fid !listeAssosPtrNameType   then   ["*"^fid]  else  [id]  in
						(assigned,   union  (listeDesVarsDeExpSeules  (expVaToExp e)) (listeDesVarsDeExpSeules  (expVaToExp i)))
					| IFVF ( _, i1, i2) 		-> 	
						let (na1, nu1)= assignVarAndUsed  [i1] in
						let (na2, nu2)= assignVarAndUsed  [i2] in
						(union  na1    na2, union  nu1    nu2)	
					| IFV ( _, i1) 		-> 	assignVarAndUsed [i1]
					| BEGIN (liste)		->  assignVarAndUsed liste 
					| FORV (a, b, c, d, e,f, i,_) ->assignVarAndUsed [i]  			
					| APPEL (num, e, nom, s, CORPS c,v,r,_) -> 
						let (listVar,u) = if List.mem_assoc nom !callsListEvalAssignVar then  (let (la,lu)= List.assoc nom !callsListEvalAssignVar in (la,lu))  else assignVarAndUsed [c] in
						let globalPtr = List.filter(fun x->   List.mem x !alreadyAffectedGlobales) listVar  in
						let sorties = (match s with BEGIN(sss)-> sss |_->[]) in
						let entrees = (match e with BEGIN(sss)-> sss |_->[]) in
							(* dans used filter les entrées et les globales*) 
						let(ae, ue)=  (assignVarAndUsed entrees) in 
						let theInputsvar =union ue (List.map(fun e-> (match e with VAR (id, _,_,_)  ->id|_->"")) entrees) in
						let realUsedExtern =  List.filter(fun x->   List.mem x !alreadyAffectedGlobales||List.mem x theInputsvar) u  in
 




						let ass = 
							List.map 
											( fun sortie -> 
												(match sortie with 
													VAR (id, _,_,_) 
													| TAB (id, _, _,_,_) 
													|MEMASSIGN (id, _,_,_,_)->
														let fid = 	if  String.length id > 1 then 
														if (String.sub id  0 1)="*" then  String.sub id 1 ((String.length id)-1) else id
														else id  in 

															if List.mem_assoc fid !listeAssosPtrNameType   then  "*"^fid else fid
													|_->"")
											)sorties	in

						(union globalPtr ass,realUsedExtern)

					| APPEL (num, e, nom, s, ABSSTORE a,v,r,_) ->
						  let (listVar,u) =getAllVARAssignAndUsed a in
						  let globalPtr = List.filter(fun x->   List.mem x !alreadyAffectedGlobales) listVar  in
						  let sorties = (match s with BEGIN(sss)-> sss |_->[]) in
						  let entrees = (match e with BEGIN(sss)-> sss |_->[]) in
							(* dans used filter les entrées et les globales*)  
						  let(ae, ue)=  (assignVarAndUsed entrees) in 
						  let theInputsvar =union ue  (List.map(fun e-> (match e with VAR (id, _,_,_)  ->id|_->"")) entrees) in
						  let realUsedExtern =  List.filter(fun x->   List.mem x !alreadyAffectedGlobales||List.mem x theInputsvar) u  in

						  let ass =  
							List.map 
											( fun sortie -> 
												(match sortie with 
													VAR (id, _,_,_) 
													| TAB (id, _, _,_,_) 
													|MEMASSIGN (id, _,_,_,_)->
														let fid = 	if  String.length id > 1 then 
														if (String.sub id  0 1)="*" then  String.sub id 1 ((String.length id)-1) else id
														else id  in 

															if List.mem_assoc fid !listeAssosPtrNameType   then  "*"^fid else fid
													|_->"")
											)sorties	in


							(union globalPtr ass,realUsedExtern) in
	(union firstAs next,union firstUsed nu)
end


let rec realgetAllVARAssign   l =
(*Printf.printf "recherche %s dans liste :\n" v;afficherListeAS l;new_line ();Printf.printf "fin s liste :\n" ;*)
if l = [] then []
else 
let a = List.hd l in
let suite = List.tl l in
	match a with
		ASSIGN_SIMPLE (s, _) 	 -> 	s::realgetAllVARAssign suite
	|	ASSIGN_DOUBLE (id,_, _) 
	| 	ASSIGN_MEM (id, _, _)	->
		let fid = 	if  String.length id > 1 then 
										if (String.sub id  0 1)="*" then  String.sub id 1 ((String.length id)-1) else id
									else id  in 
		 if List.mem_assoc fid !listeAssosPtrNameType then   ("*"^fid)::(realgetAllVARAssign suite)  else  id::realgetAllVARAssign suite





and changeGlobalList  name body gl=

let  used = 
 	if AFContext.mem  !myAF name = false then
 	begin
		match body with CORPS(_) ->    (* see also increment.ml changeGlobal function
			!alreadyAffectedGlobales*) gl
			| ABSSTORE(l) ->  realgetAllVARAssign l
 	end
 	else
	begin

		match body with CORPS(_) ->  
			 	if List.mem_assoc  name !alreadyEvalFunctionAS then realgetAllVARAssign ( List.assoc name !alreadyEvalFunctionAS) 
				else assignVar (get_fct_body   name)  				 
			| ABSSTORE(l) ->  realgetAllVARAssign l
	end
		in
		let global  = List.filter(fun x-> let fid = 	if  String.length x > 1 then 
										if (String.sub x  0 1)="*" then  String.sub x 1 ((String.length x)-1) else x
									else x  in  List.mem fid !alreadyAffectedGlobales )used in

		let memAssign  = List.map(fun x->	if  String.length x > 1 then 
										if (String.sub x  0 1)="*" then  String.sub x 1 ((String.length x)-1) else x else x)(List.filter(fun x-> let fid = 	if  String.length x > 1 then 
										if (String.sub x  0 1)="*" then  String.sub x 1 ((String.length x)-1) else x
									else x  in  x != fid  )used) in

		let globalPtr = List.filter(fun x->  List.mem_assoc x !listeAssosPtrNameType  )global in
		if globalPtr != [] then (memAssign,!alreadyAffectedGlobales)  else  (memAssign,global )


and changeGlobalListPtr  name body gl=

let  used = 
 	if AFContext.mem  !myAF name = false then
 	begin
		match body with CORPS(_) ->    (* see also increment.ml changeGlobal function
			!alreadyAffectedGlobales*) gl
			| ABSSTORE(l) ->  realgetAllVARAssign l
 	end
 	else
	begin

		match body with CORPS(_) ->  
			 	if List.mem_assoc  name !alreadyEvalFunctionAS then realgetAllVARAssign ( List.assoc name !alreadyEvalFunctionAS) 
				else assignVar (get_fct_body   name)  				 
			| ABSSTORE(l) ->  realgetAllVARAssign l
	end
		in
		 
		 List.filter(fun x->   List.mem x !alreadyAffectedGlobales && List.mem_assoc x !listeAssosPtrNameType  )used 
		 



			


let rec getconsCommaExpType  t  champlistLookingFor  =

if champlistLookingFor = []  then NO_TYPE else 
match t with
	FLOAT_TYPE |INT_TYPE  ->NO_TYPE
	|UNION_TYPE s| TYPEDEF_NAME s->  
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec) with  
				TYPEDEFTYPE (typ,_) -> 
										getconsCommaExpType  typ  champlistLookingFor  
				| _->NO_TYPE
		 end
		else NO_TYPE
	|  STRUCT_TYPE s ->  
	 
		if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  
			STRUCTORUNION (l) -> 
				if champlistLookingFor = [] || l = [] then NO_TYPE
				else
				begin	
					let (champ,suitec) = (List.hd champlistLookingFor,List.tl champlistLookingFor) in
					let ((n,typ,rt),suitedec) = (List.hd l,List.tl l) in
 
					if n = champ then
						if  suitec = [] then   rt  (*trouve*)
						else getconsCommaExpType  typ  suitec  (*dans sous champs*)
					else getNextChampType  champlistLookingFor    suitedec typ(*dans autre champs*)
				end
				
			| TYPEDEFTYPE (n,_)->NO_TYPE
		 end
		else NO_TYPE

and getNextChampType lchamps   ldec t=
if lchamps = [] || ldec = [] then  NO_TYPE
else
begin	
	let (champ,suitec) = (List.hd lchamps,List.tl lchamps) in
	let ((n,typ,rt),suitedec) = (List.hd ldec,List.tl ldec) in
 
	if n = champ then
						if  suitec = [] then rt
						else getconsCommaExpType  typ  suitec  (*dans sous champs*)
	else getNextChampType  lchamps    suitedec typ(*dans autre champs*)
end

let rec get_typeEPS  ntyp = 
	match ntyp with
	 PROTO (typ, _, _)| OLD_PROTO (typ, _, _)| PTR typ | RESTRICT_PTR typ  | CONST typ | VOLATILE typ | GNU_TYPE (_, typ) | TYPE_LINE (_, _, typ) ->   get_typeEPS typ 
	| ARRAY (typ, _)->   get_typeEPS typ 
	| FLOAT (_) | DOUBLE (_) |NO_TYPE -> FLOAT_TYPE
	| NAMED_TYPE id  ->   TYPEDEF_NAME(id)
	| STRUCT (id, dec) -> 
			 	 
			let nid = if id ="" then  "_T"   else id in			
						
						let newType = STRUCT_TYPE (nid) in
						(*printfBaseType newType;*)
			if  dec != [] then newType else ((*Printf.printf "recursive type not implemented\n";*) FLOAT_TYPE)
			
	| UNION (id, dec) ->   
			let nid = if id ="" then "_T"   else id in
				  
						UNION_TYPE (nid) 
	
	| _->   INT_TYPE


(* no pointeur on pointeur neither array of ptr*)
let rec getOnlyArrayNameOfexp exp typ realT ptr=
	match exp with
		  UNARY (op, e) ->
			(match op with
			  MEMOF -> getOnlyArrayNameOfexp e typ realT true
			| ADDROF -> getOnlyArrayNameOfexp e typ realT false
			|_->"")


		| BINARY (_, exp1, exp2) ->
			let tab1  = getOnlyArrayNameOfexp exp1 typ realT ptr in
			if tab1 = "" then  getOnlyArrayNameOfexp exp2   typ realT ptr 
			else tab1 
		| CAST (t, e) ->(* if get_typeEPS  t = typ then getOnlyArrayNameOfexp e typ false ptr else "" *)getOnlyArrayNameOfexp e typ false ptr
		| VARIABLE x -> 

				let (typeElem, isTab,isptr) = 
						if existAssosArrayType x   then   (get_typeEPS (getAssosAssosArrayType x ), true, false) 
						else 	if existAssosPtrNameType x then (getAssosPtrNameType x, false, true) 
								else (INT_TYPE , false, false) in
				if isTab || isptr then  if   typeElem = typ  || realT = false then x else ""
				else ""
			 
		| INDEX (exp1, _) ->
				if ptr then ""(*we are looking for a ptr or an array name but not an element of an array not array of ptr or ptr on ptr*) 
				else
				begin
					let (tab,_) = analyseArray exp []  in if tab != "" then getOnlyArrayNameOfexp (VARIABLE tab)  typ realT ptr else getOnlyArrayNameOfexp exp1 typ realT ptr
				end
				
		| MEMBEROF (ex, c)  | MEMBEROFPTR (ex, c) 		->					
				let lid =	getInitVarFromStruct exp  in
				let id = if lid != [] then List.hd lid else (Printf.printf "not id 3876\n"; "noid") in

				 let btype = 
								if List.mem_assoc id !listAssocIdType then getBaseType (List.assoc id !listAssocIdType)
								else 
									if List.mem_assoc id !listeAssosPtrNameType then getBaseType (List.assoc id !listeAssosPtrNameType)
									else INT_TYPE  in
				
				let typeOfChamp = getconsCommaExpType btype lid  in 
				if  estPtrOuTableauAux typeOfChamp (get_typeEPS  typeOfChamp ) then if get_typeEPS typeOfChamp =typ || realT = false then id else "" else ""
		
	|_->""







(*END GETFUNCTION*)

(* TEST UTIL TEST FUNCTION *)

let isLoopOrIFId x =
let resb = 
				if (String.length x > 4) then
				begin
					let var4 = (String.sub x  0 4) in
					let var3 = (String.sub x  0 3) in
					if var3 = "ET-" || var3 = "EF-" ||  var3 = "IF-" || var3 = "tN-" || var4 = "max-" || var4 = "tni-" then true else false
				end
				else if (String.length x > 3) then 
						if (String.sub x  0 3) = "ET-" ||(String.sub x  0 3) = "EF-" ||(String.sub x  0 3) = "IF-" || (String.sub x  0 3) = "tN-" then true else false else false in
resb



let get_estAffect exp =
	match exp with
	BINARY (op, _, _) ->
	( match op with ASSIGN|ADD_ASSIGN|SUB_ASSIGN|MUL_ASSIGN|DIV_ASSIGN|MOD_ASSIGN|BOR_ASSIGN|XOR_ASSIGN|SHL_ASSIGN|SHR_ASSIGN->  true
	  |_ -> false )
	| UNARY (op, _) -> ( match op with		PREINCR | PREDECR 	| POSINCR	| POSDECR ->  true |_ -> false )
	|_ -> false	


let rec hasPtrArrayBoundConditionExp e =
match e with
		  UNARY (_, exp) ->hasPtrArrayBoundConditionExp exp 
		| BINARY (_, exp1, exp2) ->
			let (b1,e1, iv1, exp1)= hasPtrArrayBoundConditionExp exp1 in
			let (b2,e2, iv2, exp2 )= hasPtrArrayBoundConditionExp exp2 in
			if b1 && b2 = false then  (b1,e1, iv1, exp1)
			else  if b1 = false && b2 then (b2,e2, iv2, exp2 )  else (false, "", true ,NOTHING) 
		| VARIABLE id -> 
			if (String.length id > 19) then
				if (String.sub id  0 19) = "getvarTailleTabMax_" then
				begin
					let var = String.sub id 19 ((String.length id)-19) in
				(*	Printf.printf "dans hasPtrArrayBoundConditionExp, trouve %s type : \n" var;
					printfBaseType (getBaseType (List.assoc var !listAssocIdType) );*)
				    (true , var,true ,NOTHING)	
				end
				else begin(* Printf.printf "dans hasPtrArrayBoundConditionExp, autre\n" ;*)(false, "",true,NOTHING)  end
			else   (false, "",true,NOTHING) 
		| CALL(VARIABLE("getvarTailleTabMax_"), [e]) -> (*Printf.printf "dans hasPtrArrayBoundConditionExp, autre call\n" ; *)(true, "",false ,e)	 
		| CALL(_, [e]) -> (*Printf.printf "dans hasPtrArrayBoundConditionExp, autre call 2\n" ; *)
					hasPtrArrayBoundConditionExp e 
		| _ ->  (false, "",true ,NOTHING)	

let hasPtrArrayBoundCondition e = match e with MULTIPLE -> (false, "",true,NOTHING) | EXP (e) -> hasPtrArrayBoundConditionExp e 

let estNothing e = match e with MULTIPLE -> 	false | EXP (e) -> 	match e with NOTHING -> true |_-> false


let rec containtNothing e = match e with 
		NOTHING -> true
		| UNARY (_, exp) | CAST (_, exp)| EXPR_SIZEOF exp  | EXPR_LINE (exp, _, _)->containtNothing exp
		| BINARY (_, exp1, exp2) ->containtNothing exp1 || containtNothing exp2
		| QUESTION (exp1, exp2, exp3) ->containtNothing exp1 || containtNothing exp2|| containtNothing exp3
		| CALL (exp, args) ->containtNothing exp||listnothing args
		| COMMA exps ->listnothing exps
		| CONSTANT _ | VARIABLE _ | TYPE_SIZEOF _| MEMBEROF (_, _) | MEMBEROFPTR (_, _) | GNU_BODY (_, _)->false
		| INDEX (exp, idx) ->containtNothing exp || containtNothing idx
and listnothing l = 
if l = [] then false else containtNothing (List.hd l) || listnothing (List.tl l) 


let estMultipleDef v (*index*) l = match rechercheAffectVDsListeAS v (*index*) l with MULTIPLE -> true | EXP (e) -> false

let estDef v (*index*) l = match rechercheAffectVDsListeAS v (*index*) l with MULTIPLE -> true | EXP (e) -> if e=NOTHING then false else true



let rec isNoDef  expr =
	match expr with
	NOTHING 					-> true
	| UNARY (op, exp) 			-> isNoDef   exp
	| BINARY (op, exp1, exp2) 	-> isNoDef exp1 || isNoDef exp2
	| CALL (exp, args) 			->	isNoDef exp ||  traiterCOMMADEF args
	| VARIABLE (s) 				->	false
	| INDEX (n,exp) 			->	isNoDef n || isNoDef    exp
	| _ 						-> 	false
and traiterCOMMADEF args =
if args = [] then false
else isNoDef (List.hd  args) || traiterCOMMADEF (List.tl  args)


let existeAffectationVarListe var liste =
if liste = [] then false else  List.exists (fun aSCourant ->  match aSCourant with ASSIGN_SIMPLE (id, _) |ASSIGN_DOUBLE (id, _, _) |ASSIGN_MEM (id, _, _)->  id = var ) liste  
let existeAffectationVarListeSimple var liste =
if liste = [] then false else  List.exists (fun aSCourant ->  match aSCourant with ASSIGN_SIMPLE (id, _) ->  id = var|ASSIGN_DOUBLE (id, _, _) |ASSIGN_MEM (id, _, _)->false ) liste  

let existassigndouvle var liste =
		List.exists 
		(fun aSCourant ->  match aSCourant with  	ASSIGN_DOUBLE (id, _, _)  	->  id = var  |_-> false) liste



let rec existAffectVDsListeAS v (*index*) l =
(*Printf.printf "recherche %s dans liste :\n" v;afficherListeAS l;new_line ();Printf.printf "fin s liste :\n" ;*)
if l = [] then false
else 
let a = List.hd l in
let suite = List.tl l in
	match a with
		ASSIGN_SIMPLE (s, e) 	 -> 	if s = v then true else existAffectVDsListeAS v (*index*) suite
	|	ASSIGN_DOUBLE (s,e1, e2) -> 	
			if s = v (*and il faut évaluer les 2 expression index = e1*) then true
			else  existAffectVDsListeAS v (*index*) suite
	| ASSIGN_MEM (id, e1, e2)	-> 
			if id = v (*and il faut évaluer les 2 expression index = e1*) then true
			else  existAffectVDsListeAS v (*index*) suite






let isCallVarStruct lid =
if lid = [] then false
else			let x =  (List.hd lid) in
				if (String.length x> 4) then
				begin
					let var4 = (String.sub x  0 4) in
					if  var4 = "call"   then 
					begin if !vDEBUG then Printf.printf "non traite champ struct depuis appel de fonction";true end else false
				end 
				else false




(* TEST UTIL FUNCTION end*)


(* REWRITTING FUNCTION*)

let rec remplacerValPar  var nouexp expr =
	match expr with
	NOTHING 					-> NOTHING
	| UNARY (op, exp) 			-> UNARY (op, remplacerValPar   var nouexp exp)
	| BINARY (op, exp1, exp2) 	-> BINARY (op, remplacerValPar   var nouexp exp1, remplacerValPar   var nouexp exp2)
	| QUESTION (exp1, exp2, exp3) ->QUESTION (remplacerValPar   var nouexp exp1, remplacerValPar   var nouexp exp2, remplacerValPar   var nouexp exp3)
	| CALL (exp, args) 			->	CALL (exp, List.map(fun a-> remplacerValPar  var nouexp a)args)
	| VARIABLE (s) 				->	if s = var then nouexp else expr
	| INDEX (n,exp) 			->	INDEX (n, remplacerValPar  var nouexp exp);
	| CAST (typ, exp) ->CAST (typ, remplacerValPar   var nouexp  exp)
	| CONSTANT ( CONST_COMPOUND expsc)  -> CONSTANT ( CONST_COMPOUND ( List.map(fun a-> remplacerValPar  var nouexp a)expsc))
	| COMMA exps 					->	(COMMA ( List.map (fun a -> remplacerValPar  var nouexp a) exps))
	| MEMBEROF (ex, c) 			->  (match nouexp with 
											VARIABLE (v) -> MEMBEROF (remplacerValPar   var nouexp ex,   c) 
										|  	UNARY (MEMOF, VARIABLE(v)) -> MEMBEROF (remplacerValPar   var (VARIABLE(v)) ex,   c) 
					
										|_-> MEMBEROF (remplacerValPar   var nouexp ex,   c) )
	| MEMBEROFPTR (ex, c) 		->	(match nouexp with 
											VARIABLE (v) -> MEMBEROFPTR (remplacerValPar   var nouexp ex,   c) 
										|  	UNARY (ADDROF, VARIABLE(v)) -> MEMBEROFPTR (remplacerValPar   var (VARIABLE(v)) ex,   c) 
					
										|_->  MEMBEROFPTR (remplacerValPar   var nouexp ex,   c) )
	| EXPR_SIZEOF exp -> EXPR_SIZEOF (remplacerValPar   var nouexp exp )
	| EXPR_LINE (expr, _, _) ->
			remplacerValPar   var nouexp  expr
	| _ 						-> 	expr

let rec remplacerExpPar0   nouexp expr =
	if expr = nouexp then CONSTANT (CONST_INT "0")
	else
		match expr with
		NOTHING 					-> NOTHING
		| UNARY (op, exp) 			-> let ne =remplacerExpPar0   nouexp exp in if ne = CONSTANT (CONST_INT "0") then CONSTANT (CONST_INT "0") else   UNARY (op, ne)
		| BINARY (op, exp1, exp2) 	-> BINARY (op, remplacerExpPar0   nouexp exp1, remplacerExpPar0   nouexp exp2)
		| QUESTION (exp1, exp2, exp3) ->QUESTION (remplacerExpPar0   nouexp exp1, remplacerExpPar0   nouexp exp2, remplacerExpPar0   nouexp exp3)
		| CAST (typ, exp) ->  remplacerExpPar0 nouexp  exp 
		| EXPR_LINE (expr, _, _) ->
				remplacerExpPar0 nouexp  expr
		| _ 						-> 	expr







	
let rec remplacerValPar0  var expr =

	match expr with
	NOTHING 					-> NOTHING
	| UNARY (op, exp) 			-> UNARY (op, remplacerValPar0   var exp)
	| BINARY (op, exp1, exp2) 	-> BINARY (op, remplacerValPar0   var  exp1, remplacerValPar0   var exp2)
	| CALL (exp, args) 			->	CALL (exp, List.map(fun a-> remplacerValPar0  var a)args)
	| VARIABLE (s) 				->	if s = var then CONSTANT (CONST_INT "0") else expr
	| INDEX (n,exp) 			->	INDEX (n, remplacerValPar0   var exp); 
	| CONSTANT ( CONST_COMPOUND expsc)  -> CONSTANT ( CONST_COMPOUND ( List.map(fun a-> remplacerValPar0  var  a)expsc))
	| COMMA exps 					->	(COMMA ( List.map (fun a -> remplacerValPar0  var  a) exps))
	| _ 						-> 	expr

(*		| MEMOF -> ("*", 13)
		| ADDROF -> ("&", 13)*)

let rec mapVar fct = function 
         NOTHING				-> NOTHING
	|UNARY (op, exp)			-> UNARY (op, mapVar fct exp)
	| BINARY (op, exp1, exp2) 		-> BINARY (op, mapVar fct exp1, mapVar fct exp2)
	| CALL (exp, args) 			->	CALL (exp, List.map(fun a-> mapVar fct a)args)
	| VARIABLE (s) 				->	VARIABLE (fct s)
	| INDEX (n,exp) 			->	INDEX (n, mapVar fct exp)
	| CONSTANT ( CONST_COMPOUND expsc)  -> CONSTANT ( CONST_COMPOUND ( List.map(fun a-> mapVar fct a)expsc))
	| COMMA exps 					->	(COMMA ( List.map (fun a -> mapVar fct a) exps))
	| expr 					-> 	expr
	
let rec remplacerNOTHINGPar  expr =
	match expr with
	NOTHING 					-> VARIABLE ("NODEF") 
	| UNARY (op, exp) 			-> UNARY (op, remplacerNOTHINGPar    exp)
	| BINARY (op, exp1, exp2) 	-> BINARY (op, remplacerNOTHINGPar exp1, remplacerNOTHINGPar exp2)
	| CALL (exp, args) 			->	CALL (exp, List.map(fun a-> remplacerNOTHINGPar a)args)
	| VARIABLE (s) 				->	expr
	| INDEX (n,exp) 			->	INDEX (n, remplacerNOTHINGPar    exp)

	| _ 						-> 	expr



let rec remplacergetvarTailleTabMaxFctPar  expr ne =
	match expr with
	NOTHING 					-> NOTHING
	| UNARY (op, exp) 			-> UNARY (op, remplacergetvarTailleTabMaxFctPar    exp ne)
	| BINARY (op, exp1, exp2) 	-> BINARY (op, remplacergetvarTailleTabMaxFctPar exp1 ne, remplacergetvarTailleTabMaxFctPar exp2 ne)
	| CALL(VARIABLE("getvarTailleTabMax_"), _)-> ne
	| CALL (exp, args) 			->	CALL (exp, List.map(fun a-> remplacergetvarTailleTabMaxFctPar a ne )args)
	| _ 						-> 	expr



let remplacerNOTHINGParAux e =
match e with MULTIPLE ->VARIABLE ("NODEF") | EXP (e) -> if e = NOTHING then VARIABLE ("NODEF")  else remplacerNOTHINGPar e 

(* REWRITTING FUNCTION end*)


(* CASTING FUNCTION*)	


let asToListeAffect a =
match a with
		ASSIGN_SIMPLE (s, e) 	 ->	new_instVar s e 	
	|	ASSIGN_DOUBLE (s,e1, e2) ->	new_instTab s e1 e2
	|	ASSIGN_MEM (id, e1, e2)	->  new_instMem id e1 e2 


let rec listeAsToListeAffect l =
if l = [] then [] else List.append [asToListeAffect (List.hd l)] (listeAsToListeAffect (List.tl l))



(* CASTING FUNCTION END *)	



(* PRINTING FUNCTION*)
		
let print_expVA e = match e with MULTIPLE -> Printf.printf "MULTIPLEDEF \n"| EXP (e) -> if e = NOTHING then Printf.printf "NOTHING" else print_expression e 0



let afficherAS a =
match a with
		ASSIGN_SIMPLE (s, e) 	 -> 
		(match e with EXP(ex) ->print_expression  (BINARY(ASSIGN, VARIABLE(s),  ex)) 0
						|_->print_expression  (BINARY(ASSIGN,VARIABLE(s), VARIABLE("NODEF"))) 0)
	|	ASSIGN_DOUBLE (s,e1, e2) -> 
		
			(match e1 with EXP(e) ->  
						(match e2 with EXP(ex) ->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  e),  ex)) 0
						 	|_->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  e),  VARIABLE("?"))) 0)
					| _->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  VARIABLE("NODEF")),  VARIABLE("NODEF"))) 0)
				 
	|   ASSIGN_MEM (s, e1, e2)	-> 		(*Printf.printf "mem assign affich\n";*)
			(match e1 with EXP(e) ->  
						(match e2 with EXP(ex) ->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  e),  ex)) 0
						 	|_->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  e),  VARIABLE("NODEF"))) 0)
					| _->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  VARIABLE("NODEF")),  VARIABLE("NODEF"))) 0)

let afficherListeAS asL =space(); new_line() ;flush(); List.iter (fun a-> afficherAS a; space(); new_line() ;flush(); )asL



let rec afficherLesAffectations listeAffect = List.iter (fun affect -> afficherUneAffect affect; flush();flush(); space(); new_line ()) listeAffect
and afficherUneAffect affect =
	Printf.printf "\t\t\t\t\t";
	match affect with
	 VAR ( id, expVA1,_,_) 				->	 Printf.printf "%s  <- " id ;  flush (); print_expVA expVA1; flush(); space();
	|  MEMASSIGN ( id, expVA1, expVA2,_,_)	->	 Printf.printf "%s  <- (" id ; flush (); print_expVA expVA1; flush(); space();
																 Printf.printf " ) <- ";flush(); space(); 
											 flush (); print_expVA expVA2; flush(); space();
	| TAB ( id, expVA1, expVA2,_,_) 	->   Printf.printf "%s  [" id ; flush (); print_expVA expVA1; flush(); space();
										 Printf.printf " ] <- "; print_expVA expVA2; 	flush(); space();
	| IFVF ( expVA1, i1, i2) 		->
			Printf.printf  "if (";	print_expVA expVA1;flush(); space(); Printf.printf  ")"; new_line (); 
			Printf.printf "{";		indent (); afficherUneAffect i1;flush(); space(); new_line (); unindent ();
			Printf.printf "}";new_line ();
			Printf.printf  "else "; 
			Printf.printf "{";		indent (); afficherUneAffect i2; flush(); space();	unindent ();
			Printf.printf "}"; new_line ()
	| IFV ( expVA1, i1) 		->
			Printf.printf  "if (";	print_expVA expVA1; flush(); space();Printf.printf  ")"; new_line (); 
			Printf.printf "{";		indent (); afficherUneAffect i1; unindent ();
			Printf.printf "}"; new_line ()
	| BEGIN (liste)			->  afficherLesAffectations liste; new_line ()	;	flush(); space();			
	| FORV ( num, id, expVA1, expVA2, expVA3, _, i,c) -> 	
			Printf.printf "num loop %d\n" num; Printf.printf "/* %s" id ; flush();Printf.printf " */\nfor ("; flush(); space();
			new_line ();  print_expVA expVA1;flush(); space(); Printf.printf "; ";	print_expVA expVA2; flush(); space();Printf.printf "; " ;
			print_expVA expVA3;  new_line () ; Printf.printf ")\n" ;
			Printf.printf "{";		indent (); afficherUneAffect i; flush(); space(); unindent ();
			Printf.printf "}"; new_line ()
	| APPEL (num, avant, nom, apres,CORPS c,_,_,_) ->
			Printf.printf  "\n\t\t\t\tFUNCTION CALL INPUT APPEL numbero %d %s \n" num nom; 
			afficherUneAffect avant;new_line () ;
			Printf.printf  "\n\t\t\t\tFUNCTION CORPS(VRAI CORPS) APPEL numbero %d\n" num; 
			afficherUneAffect c;new_line () ; 
			Printf.printf  "\t\t\t\t NAME %s\n" nom; 
			Printf.printf  "\t\t\t\t FUNCTION CALL OUTPUT\n"; 
			afficherUneAffect apres;new_line () ;flush(); space();
Printf.printf  "\t\t\t\t FIN  OUTPUT %d %s\n" num nom;  
	| APPEL (num, avant, nom, apres,ABSSTORE a,_,_,_) ->
			Printf.printf  "\n\t\t\t\tFUNCTION CALL INPUT APPEL numbero %d %s \n" num nom; 
			afficherUneAffect avant;new_line () ;
			Printf.printf  "\n\t\t\t\tFUNCTION CORPS(ABSTRACT STORE) APPEL numbero %d\n" num; 
			 afficherListeAS a ; print_string "PAS AFFICHE" ;new_line () ; 
			Printf.printf  "\t\t\t\t NAME %s\n" nom; 
			Printf.printf  "\t\t\t\t FUNCTION CALL OUTPUT\n"; 
			afficherUneAffect apres;new_line () ;flush(); space();
Printf.printf  "\t\t\t\t FIN  OUTPUT %d %s\n" num nom;  
Printf.printf  "\n\t\t\t\tFUNCTION CALL INPUT APPEL numbero %d %s FIN \n" num nom

let afficherListeDesFctAS liste=
if liste <> [] then
begin
	Printf.printf "AFFICHER LISTE DES ASSOS\n";
	List.iter (fun (n,asL)->  new_line ();Printf.printf n;new_line ();afficherListeAS asL;new_line ();new_line ()  ) liste  ;						
	Printf.printf "AFFICHER FIN LISTE DES ASSOS\n"
end


(* PRINTING FUNCTION end*)		


(* global byType *)

let isAddedVar id=
if (String.length id > 6) then
begin
	let var6 = (String.sub id  0 6) in
	let var4 = (String.sub id  0 4) in
	let var3 = (String.sub id  0 3) in
	if  var6 = "__tmp_" || var3 = "IF-" || var4 = "TWH-" then true else false
end
else if (String.length id > 4) then
		begin
			let var4 = (String.sub id  0 4) in
			let var3 = (String.sub id  0 3) in  
			if  var3 = "IF-" || var4 = "TWH-" then true else false
		end
		else if (String.length id > 3) then 
					if (String.sub id  0 3) = "IF-"   then true else false
					else false



let filterAddedVar l=
List.filter (fun id -> isAddedVar id=false) l
 


let (listOfGlobalByType: (newBaseType * expression list)list ref) = ref []
 

let rec setlistOfGlobalByType exp typ liste =
match 	liste with
		| [] ->[(typ, [exp])]
		| (np, vp)::sp ->
		 
			if typ < np then (typ, [exp])::liste 
			else if typ = np then (typ, exp::vp )::sp 
				 else (np, vp)::(setlistOfGlobalByType exp typ  sp  )

let realGlobal =   List.filter (fun x-> List.mem x !listEnumId = false) !alreadyAffectedGlobales  

 
let rec consForVar l=
match 	l with
		| [] ->[]
		| v::sp ->if List.mem_assoc v !listAssocIdType then
		 ( 
			let itsType = (List.assoc v !listAssocIdType) in
			setlistOfGlobalByType (VARIABLE v)  itsType (consForVar sp)
		 )
		else (Printf.printf"pb avec type of %s\n" v; (consForVar sp))



let conslistOfGlobalByType globale =
 
	let globalNotEnum = List.filter (fun x-> List.mem x !listEnumId = false) globale in 
	listOfGlobalByType := consForVar globalNotEnum 


let rec printGlobalByType l =
match 	l with
		| [] ->new_line () ;flush(); ()
		| (t,lv)::sp ->flush();
			printfBaseTypeRestrict t; Printf.printf": ";List.iter (fun exp->print_expression  exp 0 ; space())lv;new_line () ;flush(); 
		printGlobalByType sp

let getGlobalByType t = (* if it is empty the extern are input / output of the function *)
if List.mem_assoc t !listOfGlobalByType then List.assoc t !listOfGlobalByType else []


(*function inputs outputs *)

	type typeES =
	  ENTREE of string
	| SORTIE of string
	| ENTREESORTIE of string 


let numPar = ref 0 
let (listeDesNomsDeFonction: (int * string * base_type* typeES list)list ref) = ref []

	let existeNomFonctionDansListe nom  = 
	      let rep =  (List.exists (fun (_,nomF,_,_) -> (nomF = nom) ) !listeDesNomsDeFonction    ) in
		(*if rep = false then Printf.printf"existeNomFonctionDansListe %s = false\n" nom; *)
		rep
	

	let tupleNumNomFonctionDansListe nom  = List.find (fun (_,nomF,_,_) ->  (nomF = nom)  ) !listeDesNomsDeFonction  


let rec consGlobal l= 
List.map (fun x->
 ASSIGN_SIMPLE (x,MULTIPLE)
	)l

 (*
let isPtrMemAssign x=
 let fid = 	if  String.length x > 1 then 
										if (String.sub x  0 1)="*" then  String.sub x 1 ((String.length x)-1) else x
									else x  in List.mem fid !alreadyAffectedGlobales )used in
if List.mem_assoc x !listeAssosPtrNameType  then true else false

*)



let rec getconsCommaExpType  t  champlistLookingFor  =

if champlistLookingFor = []  then NO_TYPE else 
match t with
	FLOAT_TYPE |INT_TYPE  ->NO_TYPE
	|UNION_TYPE s| TYPEDEF_NAME s->  
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec) with  
				TYPEDEFTYPE (typ,_) -> 
										getconsCommaExpType  typ  champlistLookingFor  
				| _->NO_TYPE
		 end
		else NO_TYPE
	|  STRUCT_TYPE s ->  
	 
		if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  
			STRUCTORUNION (l) -> 
				if champlistLookingFor = [] || l = [] then NO_TYPE
				else
				begin	
					let (champ,suitec) = (List.hd champlistLookingFor,List.tl champlistLookingFor) in
					let ((n,typ,rt),suitedec) = (List.hd l,List.tl l) in
 
					if n = champ then
						if  suitec = [] then   rt  (*trouve*)
						else getconsCommaExpType  typ  suitec  (*dans sous champs*)
					else getNextChampType  champlistLookingFor    suitedec typ(*dans autre champs*)
				end
				
			| TYPEDEFTYPE (n,_)->NO_TYPE
		 end
		else NO_TYPE





and getNextChampType lchamps   ldec t=
if lchamps = [] || ldec = [] then  NO_TYPE
else
begin	
	let (champ,suitec) = (List.hd lchamps,List.tl lchamps) in
	let ((n,typ,rt),suitedec) = (List.hd ldec,List.tl ldec) in
 
	if n = champ then
						if  suitec = [] then rt
						else getconsCommaExpType  typ  suitec  (*dans sous champs*)
	else getNextChampType  lchamps    suitedec typ(*dans autre champs*)
end


let rec simplifierValeur exp =
 match exp with
		UNARY (MEMOF, exp1)->
			 (match exp1 with UNARY (ADDROF, next) ->  simplifierValeur  next |_->exp	 )
						 
		|UNARY (ADDROF, exp1)->    	
			(match exp1 with  UNARY (MEMOF, next) ->   simplifierValeur  next |_->exp)
		|_-> exp



(* no pointeur on pointeur neither array of ptr*)
let rec getOnlyArrayNameOfexp exp typ realT ptr=
	match   simplifierValeur exp  with
		  UNARY (op, e) ->
			(match op with
			  MEMOF -> getOnlyArrayNameOfexp e typ realT true
			| ADDROF -> getOnlyArrayNameOfexp e typ realT false
			| PREINCR  -> getOnlyArrayNameOfexp e typ realT  ptr
			| POSINCR -> getOnlyArrayNameOfexp e typ realT  ptr
			| PREDECR  -> getOnlyArrayNameOfexp e typ realT  ptr
			| POSDECR ->  getOnlyArrayNameOfexp e typ realT  ptr
			|_->"")


		| BINARY (_, exp1, exp2) ->
			let tab1  = getOnlyArrayNameOfexp exp1 typ realT ptr in
			if tab1 = "" then  getOnlyArrayNameOfexp exp2   typ realT ptr 
			else tab1 
		| CAST (t, e) -> (*if get_typeEPS   t = typ then getOnlyArrayNameOfexp e typ false ptr else "" *)getOnlyArrayNameOfexp e typ false ptr 
		| VARIABLE x -> 

				let (typeElem, isTab,isptr) = 
						if existAssosArrayType x   then   ( get_typeEPS  (getAssosAssosArrayType x ), true, false) 
						else 	if existAssosPtrNameType x then (getAssosPtrNameType x, false, true) 
								else (INT_TYPE , false, false) in
				if isTab || isptr then  if   typeElem = typ  || realT = false then x else ""
				else ""
			 
		| INDEX (exp1, _) ->
				if ptr then ""(*we are looking for a ptr or an array name but not an element of an array not array of ptr or ptr on ptr*) 
				else
				begin
					let (tab,_) = analyseArray exp []  in if tab != "" then getOnlyArrayNameOfexp (VARIABLE tab)  typ realT ptr else getOnlyArrayNameOfexp exp1 typ realT ptr
				end
				
		| MEMBEROF (ex, c)  | MEMBEROFPTR (ex, c) 		->					
				let lid =	getInitVarFromStruct exp  in
				let id = if lid != [] then List.hd lid else (Printf.printf "not id 3876\n"; "noid") in

				 let btype = 
								if List.mem_assoc id !listAssocIdType then getBaseType (List.assoc id !listAssocIdType)
								else 
									if List.mem_assoc id !listeAssosPtrNameType then getBaseType (List.assoc id !listeAssosPtrNameType)
									else INT_TYPE  in
				
				let typeOfChamp = getconsCommaExpType btype lid  in 
				if  estPtrOuTableauAux typeOfChamp (get_typeEPS  typeOfChamp ) then if get_typeEPS  typeOfChamp =typ || realT = false then id else "" else ""
		
	|_->""

let getVarPtrDep id exp myType=
   let listeDesVar = listeDesVarsDeExpSeulesTab (expVaToExp exp) in
   if  List.mem id listeDesVar= true  then ([],false)
   else 
		if listeDesVar = [] then  ([Printf.sprintf "_extern_%s" id],true)
		else 
		 	if List.tl listeDesVar = [] then (*only one var *)(listeDesVar,true )
			else  (*filterSameTypePtrOrArray listeDesVar myType  exp*)
			begin
				let nv = getOnlyArrayNameOfexp (expVaToExp exp) myType true true in if nv ="" then ((*Printf.printf "filterSameTypePtrOrArray  %s " id;print_expression (expVaToExp exp) 0; *) ([Printf.sprintf "_extern_%s" id],false))else ([nv], false)
			end


let rec getVarPtrOrArrayDep exp =
   let listeDesVar = listeDesVarsDeExpSeulesTab  exp in
  
		if listeDesVar = [] then ("",NOTHING,false)
		else  getVarPtrOrArrayDepAux  (simplifierValeur exp)  true 

and getVarPtrOrArrayDepAux exp  ptr=
	
	match    exp  with
		  UNARY (op, e) ->
			(match op with
			  MEMOF -> getVarPtrOrArrayDepAux e  true
			| ADDROF -> getVarPtrOrArrayDepAux e  false
			| PREINCR  -> 	getVarPtrOrArrayDepAux e ptr
			| POSINCR -> 	getVarPtrOrArrayDepAux e ptr
			| PREDECR  ->   getVarPtrOrArrayDepAux e ptr
			| POSDECR ->    getVarPtrOrArrayDepAux e ptr
			|_->("",NOTHING, false))


		| BINARY (_, exp1, exp2) ->
			let (tab1,exp1,iss1)  = getVarPtrOrArrayDepAux exp1   ptr in
			if tab1 = "" then  getVarPtrOrArrayDepAux exp2     ptr 
			else (tab1,exp1,iss1) 
		| CAST (t, e) -> getVarPtrOrArrayDepAux e   ptr 
		| VARIABLE x -> 

				let (isTab,isptr) = 
						if existAssosArrayType x   then   ( true, false) 
						else 	if existAssosPtrNameType x then (false, true) 
								else (false, false) in
				if isTab || isptr then   (x,exp, false) else ("",NOTHING, false)
				
			 
		| INDEX (exp1, _) ->
				if ptr then ("",NOTHING, false) (*we are looking for a ptr or an array name but not an element of an array not array of ptr or ptr on ptr*) 
				else
				begin
					let (tab,_,iss) =  getVarPtrOrArrayDepAux exp1 ptr  in    (tab,  exp, iss) 
				end
				
		| MEMBEROF (ex, c)  | MEMBEROFPTR (ex, c) 		->					
				let lid =	getInitVarFromStruct exp  in
				let id = if lid != [] then List.hd lid else (Printf.printf "not id 3876\n"; "noid") in


				 let btype = 
								if List.mem_assoc id !listAssocIdType then getBaseType (List.assoc id !listAssocIdType)
								else 
									if List.mem_assoc id !listeAssosPtrNameType then getBaseType (List.assoc id !listeAssosPtrNameType)
									else INT_TYPE  in				
				let typeOfChamp = getconsCommaExpType btype lid  in 
				if  estPtrOuTableauAux typeOfChamp (get_typeEPS  typeOfChamp ) then (id,exp, true) else ("",NOTHING, false)
	|_->("",NOTHING, false)



 



