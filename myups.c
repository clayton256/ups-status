


#include "CoreFoundation/CoreFoundation.h"
#include "IOKit/ps/IOPowerSources.h"
#include "IOKit/ps/IOPSKeys.h"

static CFStringRef g_power_source_name = NULL;

void mylogger(int n, char * f, ...)
{
    va_list argptr;
    va_start(argptr, f);
    vfprintf(stderr, f, argptr);
    va_end(argptr);
}

	
/* Copy the current power dictionary.
 *
 * Caller must release power dictionary when finished with it.
 */
static CFDictionaryRef copy_power_dictionary(CFStringRef power_source_name)
{
    CFTypeRef power_sources_info, power_source;
    CFArrayRef sources_list;
    CFDictionaryRef this_power_dictionary, power_dictionary = NULL;
    CFStringRef this_power_source_name;
    CFIndex num_keys, index;

    power_sources_info = IOPSCopyPowerSourcesInfo();

    assert(power_sources_info);
    mylogger(6, "%s: Got power_sources_info:\n", __func__);
    CFShow(power_sources_info);

    mylogger(5, "power_source_name = ");
    CFShow(power_source_name);
    mylogger(6, "end power_source_name\n");

    sources_list = IOPSCopyPowerSourcesList(power_sources_info);

    num_keys = CFArrayGetCount(sources_list);
    for(index=0; index < num_keys; index++) {
        mylogger(6, "%s: Getting power source %ld/%ld...", __func__, index+1, num_keys);
        power_source = CFArrayGetValueAtIndex(sources_list, index);
        assert(power_source);

        mylogger(6, "%s: power source %ld = ", __func__, index+1);
        CFShow(power_source);

        this_power_dictionary = IOPSGetPowerSourceDescription(power_sources_info, power_source);
        assert(this_power_dictionary);

        this_power_source_name = CFDictionaryGetValue(this_power_dictionary, CFSTR(kIOPSNameKey));
        assert(this_power_source_name);

        if(!CFStringCompare(this_power_source_name, power_source_name, 0)) {
            power_dictionary = this_power_dictionary;
            CFRetain(power_dictionary);
            break;
        }
    }

    if(power_dictionary) {
        mylogger(5, "CFShowing 'power_dictionary'");
        CFShow(power_dictionary);
    }

    /* Get a new power_sources_info next time: */
    CFRelease(power_sources_info);
    CFRelease(sources_list);

    return power_dictionary;
}

int main()
{

   char device_name_buf[256] = "";
   CFStringRef device_type_cfstr, device_name_cfstr;
   CFPropertyListRef power_dictionary;
   CFNumberRef max_capacity;
   double max_capacity_value = 100.0;

   mylogger(1, "upsdrv_initinfo()");

   power_dictionary = copy_power_dictionary(g_power_source_name);

    device_type_cfstr = CFDictionaryGetValue(power_dictionary, CFSTR(kIOPSTypeKey));
    if(device_type_cfstr && !CFStringCompare(device_type_cfstr, CFSTR(kIOPSInternalBatteryType), 0)) {
        printf("battery");
    }

    mylogger(2, "Getting 'Name' key");

    device_name_cfstr = CFDictionaryGetValue(power_dictionary, CFSTR(kIOPSNameKey));

    if (!device_name_cfstr) {
        printf("Couldn't retrieve 'Name' key from power dictionary.");
        exit(EXIT_FAILURE);
    }

    CFRetain(device_name_cfstr);

    CFStringGetCString(device_name_cfstr, device_name_buf, sizeof(device_name_buf), kCFStringEncodingUTF8);
    mylogger(2, "Got name: %s", device_name_buf);

    CFRelease(device_name_cfstr);

    max_capacity = CFDictionaryGetValue(power_dictionary, CFSTR(kIOPSMaxCapacityKey));
    if(max_capacity) {
        CFRetain(max_capacity);

        CFNumberGetValue(max_capacity, kCFNumberDoubleType, &max_capacity_value);
        CFRelease(max_capacity);

        mylogger(3, "Max Capacity = %.f units (usually 100)", max_capacity_value);
        if(max_capacity_value != 100.0) {
            mylogger(1, "Max Capacity: %f != 100", max_capacity_value);
        }
    }

    /* upsh.instcmd = instcmd; */
    CFRelease(power_dictionary);
}
