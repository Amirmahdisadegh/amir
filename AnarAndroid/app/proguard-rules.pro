# Keep the gomobile-generated libbox bindings.
-keep class libbox.** { *; }
-keep class go.** { *; }

# Keep model classes used by Gson reflection.
-keep class app.anar.android.core.** { *; }
