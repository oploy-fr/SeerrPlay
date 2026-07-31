# Room creates database implementations through reflection. R8 full mode can
# otherwise remove their no-argument constructors from optimized release APKs.
-keep class * extends androidx.room.RoomDatabase {
    public <init>();
}
