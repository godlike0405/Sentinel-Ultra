## Summary

Allocation-heavy Wii U homebrew currently slows down because RPX programs rely
on the CafeOS default heap for C allocation. Move RPX allocation to newlib using
the available MEM2 storage, without changing the behavior callers rely on.

## Expected behavior

- In an RPX, standard C allocation and calls through the CafeOS default-heap
  interface use the same newlib-backed allocation system. Allocation, release,
  and aligned allocation retain their existing public behavior.
- The allocator is ready before the loader or application can depend on it.
  On the default startup path, setup is complete before control reaches
  application code. Applications can still provide their existing
  `__preinit_user` override to opt out of the new default.
- RPL modules do not reconfigure the process-wide default heap. They remain
  compatible with the legacy `wutmalloc` path, including initialization during
  module loading. Legacy allocator initialization belongs to RPL startup rather
  than shared runtime initialization. Neither RPL startup nor shared runtime
  initialization may run the RPX-specific default-heap setup, including
  indirectly through another initializer.
- The newlib heap is limited only by the allocatable MEM2 region supplied at
  startup. Legacy allocator size controls must not reduce that capacity.
- Concurrent and interrupt-sensitive allocation must serialize without
  deadlock or overlapping critical sections. Synchronization for these short
  critical sections must not sleep or depend on scheduler progress while held.
- Normal runtime shutdown must invoke the newlib heap teardown and release the
  reserved MEM2 storage; merely providing a cleanup routine is not sufficient.
  The allocation lifecycle must continue to work through startup and shutdown.

Preserve the existing platform ABI, newlib syscall ABI, public allocation APIs,
and user-overridable startup behavior. Any new implementation code must be part
of the normal library build.

## Build

Build and install `wut` with the devkitPPC toolchain:

```
make -j"$(nproc)" && make install
```

All affected code must compile with that toolchain and be included in the
library build.
