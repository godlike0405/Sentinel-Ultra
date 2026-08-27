`StrBuilder` does not consistently protect sensitive character data. Content discarded by truncation or replacement can remain recoverable, including through later growth or serialization, bulk ingestion can allow a hostile input to observe or corrupt builder state, storage abandoned by capacity changes keeps its character data, and serialized instances expose the entire backing capacity instead of only the logical content.

Harden every operation that reduces the logical length, including `setLength(int)` and every replacement operation whose new text is shorter than the removed text. Discarded characters must no longer be recoverable: positions exposed by later growth contain NUL (`'\0'`), and serialized instances contain no discarded suffix. Retained content and capacity must remain unchanged by the reduction, and the guarantee must continue to hold across consecutive reductions.

Preserve the rest of the existing `setLength` contract: negative lengths throw `StringIndexOutOfBoundsException`; growing the builder expands capacity when necessary and exposes only NUL characters; setting the current length is a no-op; the method returns the same builder; and `length()`, `size()`, and `toString()` continue to reflect the requested logical length and content.

Extend the hardening to the storage lifecycle itself. Whenever any operation replaces the backing storage, every position of the abandoned storage must contain NUL by the time the operation returns, no matter what triggered the replacement. The replacement must otherwise remain invisible: retained content, logical length, and the resulting capacity follow the existing behavior, and storage that is not replaced is left untouched.

Serialization must expose exactly the logical content and nothing else. Builders holding equal content must produce identical serialized bytes regardless of their current capacity or how that capacity evolved. Deserialization restores the content and logical length, yields an instance whose capacity equals its length, and produces a builder that behaves under subsequent operations exactly like a normally constructed one. Serializing an unmodified deserialized copy reproduces the original bytes.

Harden bulk ingestion from untrusted inputs. A successful `readFrom(Readable)` call must preserve the existing prefix, consume input through end-of-input, append the supplied characters, and return the appended character count. For a `CharBuffer`, success advances its position to its limit. A hostile `Reader` or other `Readable` must not be able to observe or corrupt pre-existing builder content. Once the call finishes, whether successfully or exceptionally, no ingested character data may remain accessible through the input.

Bulk reads must be failure-atomic. If an input throws an `IOException` or runtime exception before reaching end-of-input, the builder retains exactly its pre-call value. Invalid character counts, including counts inconsistent with the amount of data supplied, fail with `IOException` without changing the builder.

Add the public overload `int readFrom(Readable readable, int maxChars) throws IOException`. It provides the same successful behavior while accepting at most `maxChars` characters. A negative limit throws `IllegalArgumentException`, a null input throws `NullPointerException`, and exceeding the limit throws `IOException`. Exactly the limit is valid, while a zero limit accepts only empty input. Any rejected call leaves the builder unchanged. The existing one-argument overload remains unbounded.

Extend the existing public array-fill utility with range overloads for character arrays:

- `char[] clear(char[] array, int fromIndex, int toIndex)` overwrites the half-open range `[fromIndex, toIndex)` with NUL characters.
- `char[] fill(char[] array, int fromIndex, int toIndex, char value)` overwrites the half-open range `[fromIndex, toIndex)` with `value`.

Both overloads return the same array reference, return `null` when given a null array, leave positions outside the requested range unchanged, and treat an empty range as a no-op. For a non-null array, invalid ranges must raise the same exception types as `java.util.Arrays.fill(char[], int, int, char)`.
