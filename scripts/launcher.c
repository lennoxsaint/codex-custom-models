#include <CoreFoundation/CoreFoundation.h>
#include <mach-o/dyld.h>

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>


static char *copy_info_string(CFStringRef key) {
    CFBundleRef bundle = CFBundleGetMainBundle();
    if (bundle == NULL) return NULL;
    CFDictionaryRef info = CFBundleGetInfoDictionary(bundle);
    if (info == NULL) return NULL;
    CFTypeRef raw = CFDictionaryGetValue(info, key);
    if (raw == NULL || CFGetTypeID(raw) != CFStringGetTypeID()) return NULL;
    CFStringRef value = (CFStringRef)raw;
    CFIndex size = CFStringGetMaximumSizeForEncoding(CFStringGetLength(value), kCFStringEncodingUTF8) + 1;
    char *buffer = calloc((size_t)size, 1);
    if (buffer == NULL) return NULL;
    if (!CFStringGetCString(value, buffer, size, kCFStringEncodingUTF8)) {
        free(buffer);
        return NULL;
    }
    return buffer;
}


int main(int argc, char **argv) {
    char *codex_home = copy_info_string(CFSTR("CCMCodexHome"));
    char *user_data = copy_info_string(CFSTR("CCMElectronUserDataPath"));
    char *real_name = copy_info_string(CFSTR("CCMRealExecutable"));
    if (codex_home == NULL || user_data == NULL || real_name == NULL) {
        fputs("Custom-model launcher is missing required bundle metadata.\n", stderr);
        free(codex_home);
        free(user_data);
        free(real_name);
        return 78;
    }

    uint32_t path_size = PATH_MAX;
    char executable_path[PATH_MAX];
    if (_NSGetExecutablePath(executable_path, &path_size) != 0) {
        fputs("Could not resolve the custom-model launcher path.\n", stderr);
        free(codex_home);
        free(user_data);
        free(real_name);
        return 78;
    }
    char *separator = strrchr(executable_path, '/');
    if (separator == NULL) {
        free(codex_home);
        free(user_data);
        free(real_name);
        return 78;
    }
    *separator = '\0';

    char real_path[PATH_MAX];
    if (snprintf(real_path, sizeof(real_path), "%s/%s", executable_path, real_name) >= (int)sizeof(real_path)) {
        fputs("Copied ChatGPT executable path is too long.\n", stderr);
        free(codex_home);
        free(user_data);
        free(real_name);
        return 78;
    }
    size_t user_data_arg_size = strlen(user_data) + strlen("--user-data-dir=") + 1;
    char *user_data_arg = calloc(user_data_arg_size, 1);
    if (user_data_arg == NULL) {
        free(codex_home);
        free(user_data);
        free(real_name);
        return 70;
    }
    snprintf(user_data_arg, user_data_arg_size, "--user-data-dir=%s", user_data);

    setenv("CODEX_HOME", codex_home, 1);
    setenv("CODEX_ELECTRON_USER_DATA_PATH", user_data, 1);
    free(codex_home);
    free(user_data);
    free(real_name);

    char **child_argv = calloc((size_t)argc + 2, sizeof(char *));
    if (child_argv == NULL) {
        free(user_data_arg);
        return 70;
    }
    child_argv[0] = real_path;
    child_argv[1] = user_data_arg;
    for (int index = 1; index < argc; index += 1) child_argv[index + 1] = argv[index];
    child_argv[argc + 1] = NULL;

    execv(real_path, child_argv);
    int saved_errno = errno;
    free(child_argv);
    free(user_data_arg);
    fprintf(stderr, "Could not launch copied ChatGPT executable: %s\n", strerror(saved_errno));
    return 71;
}
