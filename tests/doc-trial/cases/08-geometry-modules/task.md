Write a reusable geometry library and a distinct client module that consumes only its published interface. The library represents coordinates in signed 32-bit units of one sixty-fourth of a pixel, exposes the raw coordinate value, and provides integer-pixel and binary64-pixel conversions, conversion back to binary64 pixels, saturating addition and subtraction, minimum and maximum, point containment, and rectangle intersection. Whole-pixel conversion and integer arithmetic saturate at the signed 32-bit limits. Binary64 conversion uses strict multiplication by 64 and rounding to the nearest integer with ties to even; values beyond the range saturate by sign, and NaN becomes zero. Conversion back divides the raw value by 64 exactly.

Rectangles include their top and left edges and exclude their bottom and right edges. Far edges use saturating coordinate addition. Two rectangles intersect only when their half-open intervals overlap on both axes; merely touching edges do not count. The client must exercise the library through its public interface.

This case uses a module graph rather than a single source file. Put `modules.wfg` in the root of `attempt/`, publish each module's interface in its own `module.wfm`, and put its implementation files with extension `.wf` beside that interface. Register both library and client in the graph with their direct dependencies. The named graph entry must be `main`, selecting the client's public entry function. Put a `build` file in `attempt/` with these four compiler arguments, one per line and in this order: `--graph`, `modules.wfg`, `--entry`, `main`. You choose the module directories and public names. Use the supplied standard-library interfaces for process startup and byte output; `std::process`, `std::fs`, `std::io`, and `std::time` provide those capabilities. Close the startup directory permissions.

The client computes the following fourteen observations in this exact order:

1. The raw coordinate obtained from two whole pixels: 128.
2. The raw coordinate from 2,147,483,647 whole pixels: 2,147,483,647.
3. The raw coordinate from -2,147,483,648 whole pixels: -2,147,483,648.
4. The raw coordinate from binary64 1.5 pixels: 96.
5. Conversion of that last coordinate back to binary64 pixels: 1.5.
6. The raw coordinate from binary64 0.0078125 pixels: 0.
7. The raw coordinate from binary64 0.0234375 pixels: 2.
8. The raw result of adding one pixel to the maximum coordinate: 2,147,483,647.
9. The raw result of subtracting one pixel from the minimum coordinate: -2,147,483,648.
10. Whether a rectangle at (10,20) pixels with size (3,4) pixels contains (10,20): true.
11. Whether it contains (12,23): true.
12. Whether it contains (13,23): false.
13. Whether it contains (12,24): false.
14. Whether it intersects a rectangle at (13,20) with size (3,4): false.

Write exactly 112 bytes to standard output: fourteen eight-byte words in the order above, with every word little-endian. Raw signed coordinate observations use signed 64-bit two's-complement encoding. Observation five uses the IEEE-754 binary64 bits of 1.5 (hexadecimal 3ff8000000000000). Boolean observations use unsigned 64-bit one for true and zero for false. Output the computed observations; do not replace the computations with the listed expected values. Complete partial output transfers until all bytes are published. Return exit status zero after successful output and one on an output error. Write nothing else to standard output or standard error. No command-line arguments or input are required.
