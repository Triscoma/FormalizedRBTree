(** * Extract: Running Coq Programs in OCaml *)

(** Coq's [Extraction] feature enables you to write a functional
    program inside Coq, use Coq's logic to prove some correctness
    properties about it, and translate it into an OCaml program that
    you can compile with your optimizing OCaml compiler.  Haskell is
    also supported. *)

(** The [Extraction] chapter of _Logical Foundations_ has
    a simple example of Coq's program extraction features, but it's
    not required reading. This chapter starts from scratch and goes
    deeper. *)

Set Warnings "-notation-overridden,-parsing,-deprecated-hint-without-locality".
From VFA Require Import Perm.
Require Extraction.
Set Extraction Output Directory ".".

(* ################################################################# *)
(** * Extraction *)

(** As an example, let's extract insertion sort, which we implemented
    in [Sort]. *)

Fixpoint ins (i : nat) (l : list nat) :=
  match l with
  | [] => [i]
  | h :: t => if i <=? h then i :: h :: t else h :: ins i t
  end.

Fixpoint sort (l : list nat) : list nat :=
  match l with
  | [] => []
  | h :: t => ins h (sort t)
  end.

(** The [Extraction] command prints out a function as OCaml code. *)

Extraction sort.

(** You can see the translation of [sort] from Coq to OCaml in
    your IDE.  Examine it there, and notice the similarities and
    differences.  To get the whole program, we need [Recursive
    Extraction]: *)

Recursive Extraction sort.

(** The first thing you see there is a redefinition of the [bool] type.
    But OCaml already has a [bool] type whose inductive structure is
    isomorphic. We want our extracted functions to be compatible
    with, i.e. callable by, ordinary OCaml code. So we want to use
    OCaml's standard definition of [bool] in place of Coq's inductive
    definition, [bool]. You'll notice the same issue with lists. The
    following directive causes Coq to use OCaml's definitions of [bool]
    and [list] in the extracted code: *)

Extract Inductive bool => "bool" [ "true" "false" ].
Extract Inductive list => "list" [ "[]" "(::)" ].
Recursive Extraction sort.

(** But the program still uses a unary representation of natural
    numbers: the number 7 is really [(S (S (S (S (S (S (S O)))))))],
    which in OCaml will be a data structure that's seven pointers
    deep. The [leb] function takes linear time, proportional to the
    difference in value between [n] and [m]. *)

(** We could instead use Coq's [Z], which is a binary representation
    of integers. But that is logarithmic-time, not constant. *)

Require Import ZArith.
Open Scope Z_scope.

Fixpoint insZ (i : Z) (l : list Z) :=
  match l with
  | [] => [i]
  | h :: t => if i <=? h then i :: h :: t else h :: insZ i t
  end.

Fixpoint sortZ (l : list Z) : list Z :=
  match l with
  | [] => []
  | h :: t => insZ h (sortZ t)
  end.

Recursive Extraction sortZ.

(** Of course, for that extraction to be meaningful, we would need
    to prove that [sortZ] is a sorting algorithm. *)

(** Other alternatives include:

    - Extract [nat] directly to OCaml [int].  But [int] is finite (2^63
      in modern implementations), so there are theorems we could prove
      in Coq that wouldn't hold in OCaml.

    - Use Coq's [Int63], which faithfully models 63-bit cyclic
      arithmetic, and extract directly to OCaml [int]. But that's
      painful.

    - Define and axiomatize our own lightweight abstract type of
      naturals, but extract it to OCaml [int].  But, this is
      dangerous! If our axioms are inconsistent, we can prove anything
      at all. If they are not faithful to OCaml, our proofs will be
      meaningless. *)

(* ################################################################# *)
(** * Lightweight Extraction to [int] *)

(** We begin by positing a Coq type [int] that will be extracted to
    OCaml's [int]: *)

Parameter int : Type.
Extract Inlined Constant int => "int".

(** We'll abstract OCaml [int] to Coq [Z].  Every [int] does have a
    representation as a [Z], though the other direction cannot
    hold. *)

Parameter Abs : int -> Z.
Axiom Abs_inj: forall (n m : int), Abs n = Abs m -> n = m.

(** Nothing else is known so far about [int]. Let's add less-than
    operators, which are extracted to OCaml's: *)

Parameter ltb: int -> int -> bool.
Extract Inlined Constant ltb => "( < )".
Axiom ltb_lt : forall (n m : int), ltb n m = true <-> Abs n < Abs m.

Parameter leb: int -> int -> bool.
Extract Inlined Constant leb => "( <= )".
Axiom leb_le : forall (n m : int), leb n m = true <-> Abs n <= Abs m.

(** Those axioms are sound: OCaml's [<] and [<=] are consistent with
    Coq's on any [int]. Note that we do not give extraction directives
    for [Abs], [ltb_lt], or [leb_le].  They will not appear in
    programs, only in proofs --which are not meant to be extracted. *)

(** You could imagine doing the same thing we just did with [( + )], but
    that would be wrong:

      Parameter ocaml_plus : int -> int -> int.
      Extract Inlined Constant ocaml_plus => "( + )".
      Axiom ocaml_plus_plus: forall a b c: int,
        ocaml_plus a b = c <-> Abs a + Abs b = Abs c.

    The first two lines are OK: there really is a [+] function in
    OCaml, and its type really is [int -> int -> int].

    But [ocaml_plus_plus] is unsound. From it, you could prove,

      Abs max_int + Abs max_int = Abs (ocaml_plus max_int max_int)

    which is not true in OCaml because of overflow.

*)

(** In [Perm] we proved several theorems showing that Boolean
    operators were reflected in propositions.  Below, we do that
    for [int] and [Z] comparisons. *)

Lemma int_ltb_reflect : forall x y, reflect (Abs x < Abs y) (ltb x y).
Proof.
  intros x y.
  apply iff_reflect. symmetry. apply ltb_lt.
Qed.

Lemma int_leb_reflect : forall x y, reflect (Abs x <= Abs y) (leb x y).
Proof.
  intros x y.
  apply iff_reflect. symmetry. apply leb_le.
Qed.

Lemma Z_eqb_reflect : forall x y, reflect (x = y) (Z.eqb x y).
Proof.
  intros x y.
  apply iff_reflect. symmetry. apply Z.eqb_eq.
Qed.

Lemma Z_ltb_reflect : forall x y, reflect (x < y) (Z.ltb x y).
Proof.
  intros x y.
  apply iff_reflect. symmetry. apply Z.ltb_lt.
Qed.

Lemma Z_leb_reflect : forall x y, reflect (x <= y) (Z.leb x y).
Proof.
  intros x y.
  apply iff_reflect. symmetry. apply Z.leb_le.
Qed.

Lemma Z_gtb_reflect : forall x y, reflect (x > y) (Z.gtb x y).
Proof.
  intros x y.
  apply iff_reflect. symmetry. rewrite Z.gtb_ltb. rewrite Z.gt_lt_iff. apply Z.ltb_lt.
Qed.

Lemma Z_geb_reflect : forall x y, reflect (x >= y) (Z.geb x y).
Proof.
  intros x y.
  apply iff_reflect. symmetry. rewrite Z.geb_leb. rewrite Z.ge_le_iff. apply Z.leb_le.
Qed.

(** Now we upgrade [bdall] to work with [Z] and [int].  *)

Hint Resolve
     int_ltb_reflect int_leb_reflect
     Z_eqb_reflect Z_ltb_reflect Z_leb_reflect Z_gtb_reflect Z_geb_reflect
  : bdestruct.

Ltac bdestruct_guard:=
  match goal with
  | |- context [ if Nat.eqb ?X ?Y then _ else _] => bdestruct (Nat.eqb X Y)
  | |- context [ if Nat.ltb ?X ?Y then _ else _] => bdestruct (Nat.ltb X Y)
  | |- context [ if Nat.leb ?X ?Y then _ else _] => bdestruct (Nat.leb X Y)
  | |- context [ if Z.eqb ?X ?Y then _ else _] => bdestruct (Z.eqb X Y)
  | |- context [ if Z.ltb ?X ?Y then _ else _] => bdestruct (Z.ltb X Y)
  | |- context [ if Z.leb ?X ?Y then _ else _] => bdestruct (Z.leb X Y)
  | |- context [ if Z.gtb ?X ?Y then _ else _] => bdestruct (Z.gtb X Y)
  | |- context [ if Z.geb ?X ?Y then _ else _] => bdestruct (Z.geb X Y)
  | |- context [ if ltb ?X ?Y then _ else _] => bdestruct (ltb X Y)
  | |- context [ if leb ?X ?Y then _ else _] => bdestruct (leb X Y)
  end.

Ltac bdall :=
  repeat (simpl; bdestruct_guard; try lia; auto).

(* ################################################################# *)
(** * Insertion Sort, Extracted *)

(** We're ready to state insertion sort with [int], and to extract it: *)

Fixpoint ins_int (i : int) (l : list int) :=
  match l with
  | [] => [i]
  | h :: t => if leb i h then i :: h :: t else h :: ins_int i t
  end.

Fixpoint sort_int (l : list int) : list int :=
  match l with
  | [] => []
  | h :: t => ins_int h (sort_int t)
  end.

Recursive Extraction sort_int.

(** Again, for that extraction to be meaningful, we need to prove that
    [sort_int] is a sorting algorithm.  We can do that with the same
    techniques we used in [Sort].  In particular, [lia] works
    with [Z], so we can enjoy automation without having to do any
    unnecessary work axiomatizing and proving lemmas about [int]. *)

Inductive sorted : list int -> Prop :=
| sorted_nil:
    sorted []
| sorted_1: forall x,
    sorted [x]
| sorted_cons: forall x y l,
    Abs x <= Abs y -> sorted (y :: l) -> sorted (x :: y :: l).

Hint Constructors sorted : core.

(** **** Exercise: 3 stars, standard (sort_int_correct) *)

(** Prove the correctness of [sort_int] by adapting your solution to
    [insertion_sort_correct] from [Sort]. Note that notations
    such as [<=?] refer to [nat] comparisons, so you might need to
    adjust those in your proof. *)

Lemma ins_int_sorted:
  forall a l, sorted l -> sorted (ins_int a l).
Proof.
  intros a l S. induction S; simpl ; bdall.
  - apply sorted_1.
  - apply sorted_cons.
      * lia.
      * apply sorted_1.
  - apply sorted_cons.
      * lia.
      * simpl in IHS. assert (leb a y = true).
        { apply leb_le. assumption. }
        rewrite H2 in IHS. assumption.
  - apply sorted_cons.
        { lia. }
        { simpl in IHS. destruct (leb a y) eqn : E.
          - apply leb_le in E. lia. 
          - assumption.  }
Qed.

Theorem sort_int_sorted: forall l, sorted (sort_int l).
Proof.
  induction l.
  - simpl. apply sorted_nil.
  - simpl. apply ins_int_sorted. assumption.
Qed.

Lemma ins_int_perm: forall x l,
    Permutation (x :: l) (ins_int x l).
Proof.
  intros x l.
  induction l.
  - simpl. apply Permutation_refl.
  - simpl. bdall. apply perm_trans with (l' := a :: x :: l). 
    + apply perm_swap.
    + apply perm_skip. assumption.
Qed.

Theorem sort_int_perm : forall l, Permutation l (sort_int l).
Proof.
  induction l.
  - simpl. apply perm_nil.
  - simpl. apply perm_trans with (l' := a :: (sort_int l)).
    + apply perm_skip. assumption.
    + apply ins_int_perm.
Qed.

Theorem sort_int_correct : forall (al : list int),
    Permutation al (sort_int al) /\ sorted (sort_int al).
Proof.
  intro al ; split.
  - apply sort_int_perm.
  - apply sort_int_sorted.
Qed.

(** [] *)

(* ################################################################# *)
(** * Binary Search Trees, Extracted *)

(** We can reimplement BSTs with [int] keys. *)

Definition key := int.

Inductive tree (V : Type) : Type :=
  | E : tree V
  | T : tree V -> key -> V -> tree V -> tree V.

Arguments E {V}.
Arguments T {V}.

Definition empty_tree {V : Type} : tree V := E.

Fixpoint lookup {V : Type} (default : V) (x : key) (t : tree V) : V :=
  match t with
  | E => default
  | T l k v r => if ltb x k then lookup default x l
                else if ltb k x then lookup default x r
                     else v
  end.

Fixpoint insert {V : Type} (x : key) (v : V) (t : tree V) : tree V :=
  match t with
  | E => T E x v E
  | T l y v' r => if ltb x y then T (insert x v l) y v' r
                 else if ltb y x then T l y v' (insert x v r)
                      else T l x v r
  end.

Fixpoint elements_aux {V : Type}
         (t : tree V) (acc : list (key * V)) : list (key * V) :=
  match t with
  | E => acc
  | T l k v r => elements_aux l ((k, v) :: elements_aux r acc)
  end.

Definition elements {V : Type} (t : tree V) : list (key * V) :=
  elements_aux t [].

Theorem lookup_empty : forall (V : Type) (default : V) (k : key),
    lookup default k empty_tree = default.
Proof. auto. Qed.

(** **** Exercise: 1 star, standard (lookup_insert_eq) *)
Theorem lookup_insert_eq :
  forall (V : Type) (default : V) (t : tree V) (k : key) (v : V),
    lookup default k (insert k v t) = v.
Proof.
  induction t; intros ; bdall.
Qed.
(** [] *)

(** **** Exercise: 2 stars, standard (lookup_insert_neq) *)
Theorem lookup_insert_neq :
  forall (V : Type) (default : V) (t : tree V) (k k' : key) (v : V),
    k <> k' -> lookup default k' (insert k v t) = lookup default k' t.
Proof.
  induction t ; intros ; bdall.
  - assert (Abs k' = Abs k). lia. apply Abs_inj in H2. symmetry in H2. apply H in H2. inversion H2.
  - assert (Abs k0 = Abs k'). lia. apply Abs_inj in H6. apply H in H6. inversion H6. 
Qed.
(** [] *)

(** **** Exercise: 4 stars, standard, optional (int_elements) *)

(** Port the definition of [BST] and re-prove the properties of
    [elements] for [int]-keyed trees. Send us your solution so
    we can include it! *)

(** [] *)

(** Now see the extraction in your IDE: *)

Extract Inductive prod => "( * )"  [ "( , )" ]. (* extract pairs natively *)
Recursive Extraction empty_tree insert lookup elements.

(* ################################################################# *)
(** * Performance Tests *)

(** Let's measure the performance of BSTs.  First, we extract to
    an OCaml file: *)

Extraction "searchtree.ml" empty_tree insert lookup elements.

(** Second, in the same directory as this file ([Extract.v])
    you will find the file [test_searchtree.ml]. You can
    run it using the OCaml toplevel with these commands:

# #use "searchtree.ml";;
# #use "test_searchtree.ml";;

On a recent machine with a 2.9 GHz Intel Core i9 that prints:

Insert and lookup 1000000 random integers in .889566 seconds.
Insert and lookup 20000 random integers in 0.009918 seconds.
Insert and lookup 20000 consecutive integers in 2.777335 seconds.

That execution uses the bytecode interpreter.  The native compiler
will have better performance:

$ ocamlopt -c searchtree.mli searchtree.ml
$ ocamlopt searchtree.cmx -open Searchtree test_searchtree.ml -o test_searchtree
$ ./test_searchtree

On the same machine that prints,

Insert and lookup 1000000 random integers in 0.488973 seconds.
Insert and lookup 20000 random integers in 0.003237 seconds.
Insert and lookup 20000 consecutive integers in 0.387535 seconds.
*)

(** Of course, the reason why the performance is so much worse with
    consecutive integers is that BSTs exhibit worst-case performance
    under that workload: linear time instead of logarithmic.  We need
    balanced search trees to achieve logarithmic.  [Redblack]
    will do that. *)

(* 2025-01-06 17:19 *)
