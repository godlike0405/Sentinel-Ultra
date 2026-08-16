Unity Helpers ships a reusable comparer that editors and tools use to present lists of Unity objects to users in a stable, name-based order. Because the comparer orders names purely as ordinal strings, any object whose name ends in a number sorts lexicographically rather than by its actual numeric value. The practical consequence is that a set of objects named `Item1`, `Item2`, `Item10` is shown to the user as `Item1`, `Item10`, `Item2` — the item numbered 10 is pushed ahead of the item numbered 2 simply because `1` precedes `2` character-by-character. People naturally expect these numbered names to appear in counting order, so the current behavior looks like a sorting bug wherever the comparer feeds a user-facing list.

The goal is to fix the name-based ordering so that numbered names sort in counting order rather than lexicographic order, while leaving all other comparison behavior intact. When both names end in a run of digits, the portion before those digits determines their primary ordering and the numeric values break ties between equal leading portions.

The observable acceptance criteria are:

1. Given two objects named `Item2` and `Item10`, `Compare` must report `Item2` as ordering before `Item10`: comparing `Item2` against `Item10` returns a negative value, and comparing `Item10` against `Item2` returns a positive value.
2. Given two objects whose trailing numbers are written with different digit widths, such as `Item001` and `Item10`, the comparison must still reflect numeric value — `Item001` (numeric 1) orders before `Item10` (numeric 10), so comparing `Item001` against `Item10` returns a negative value. Leading zeros must not change the numeric ordering.
3. Whenever exactly one of the two names has a trailing number, the name without a trailing number must order first, regardless of how the names' text would otherwise compare. For example, comparing `Item` against `Item2` returns a negative value.
4. When both names have trailing numbers, names that share the same non-numeric leading portion are ordered by the numeric value of their trailing digits. If their leading portions differ, those leading portions determine the ordering, case-insensitively as before.
5. Names that contain no trailing digits continue to compare against each other exactly as they do today, case-insensitively.
6. The existing `SortByName` collection operation must expose the same ordering for arrays, `List<T>` instances, and other `IList<T>` implementations.

All of the comparer's existing contract must be preserved: comparing an object to itself yields `0`, a null right-hand operand orders after a non-null left-hand operand (returns a positive value) while a null left-hand operand orders first (returns a negative value), and when two distinct objects still compare equal by name the existing secondary ordering (by asset/scene path where available, then by instance id) continues to apply. The comparer's public API and singleton access point remain unchanged.

Do not modify any test files.
