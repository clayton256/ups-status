/*
	From The Network UPS Tools nut/drivers/macosx-ups.c
	IO PS keys are from Apple Frameworks/IOKit/ps/IOPSKeys.h
*/
#include "CoreFoundation/CoreFoundation.h"
#include "IOKit/ps/IOPowerSources.h"
#include "IOKit/ps/IOPSKeys.h"

static CFStringRef g_power_source_name = NULL;

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
    CFShow(power_sources_info);
	
    sources_list = IOPSCopyPowerSourcesList(power_sources_info);
    CFShow(sources_list);

    num_keys = CFArrayGetCount(sources_list);
printf("num_keys %ld\n", num_keys);
    for(index=0; index < num_keys; index++) {
printf("index %ld\n", index);

        power_source = CFArrayGetValueAtIndex(sources_list, index);
        assert(power_source);
printf("power_source end\n");

	    CFShow(power_source);

        this_power_dictionary = IOPSGetPowerSourceDescription(power_sources_info, power_source);
        assert(this_power_dictionary);
printf("this_power_dictionary end\n");

        this_power_source_name = CFDictionaryGetValue(this_power_dictionary, CFSTR(kIOPSNameKey));
        assert(this_power_source_name);
	    CFShow(this_power_source_name);
printf("this_power_source_name end\n");

        if(!CFStringCompare(this_power_source_name, power_source_name, 0)) {
		   printf("compare end\n");
            power_dictionary = this_power_dictionary;
            CFRetain(power_dictionary);
            break;
        }
    }
printf("index end\n");

    if(power_dictionary) {
        CFShow(power_dictionary);
    }

    /* Get a new power_sources_info next time: */
    CFRelease(power_sources_info);
    CFRelease(sources_list);

    return power_dictionary;
}

int main()
{
   /* try to detect the UPS here - call fatal_with_errno(EXIT_FAILURE, ) if it fails */
   char device_name_buf[256] = "";
   CFStringRef device_type_cfstr, device_name_cfstr;
   CFPropertyListRef power_dictionary;
   CFNumberRef max_capacity;
   double max_capacity_value = 100.0;
   CFNumberRef current_voltage;
   signed int current_voltage_value;


   g_power_source_name = CFStringCreateWithCString(kCFAllocatorDefault, " CP 1500C", kCFStringEncodingUTF8);

   printf("before copy_power_dictionary\n");
   power_dictionary = copy_power_dictionary(g_power_source_name);
   printf("after copy_power_dictionary\n");

   if(power_dictionary)
   {
	    device_type_cfstr = CFDictionaryGetValue(power_dictionary, CFSTR(kIOPSTypeKey));
	    if(device_type_cfstr && !CFStringCompare(device_type_cfstr, CFSTR(kIOPSInternalBatteryType), 0)) {
	        printf("battery");
	    }

	    device_name_cfstr = CFDictionaryGetValue(power_dictionary, CFSTR(kIOPSNameKey));

	    if (!device_name_cfstr) {
	        printf("Couldn't retrieve 'Name' key from power dictionary.\n");
	        exit(EXIT_FAILURE);
	    }

	    CFRetain(device_name_cfstr);

	    CFStringGetCString(device_name_cfstr, device_name_buf, sizeof(device_name_buf), kCFStringEncodingUTF8);
		printf("Name: %s\n", device_name_buf);
	    CFRelease(device_name_cfstr);

	    max_capacity = CFDictionaryGetValue(power_dictionary, CFSTR(kIOPSMaxCapacityKey));
		//CFShow(max_capacity);
	    if(max_capacity) {
	        CFRetain(max_capacity);

	        CFNumberGetValue(max_capacity, kCFNumberDoubleType, &max_capacity_value);
	        CFRelease(max_capacity);
             printf("Max Capacity: %f\n", max_capacity_value);
	    }

	    current_voltage = CFDictionaryGetValue(power_dictionary, CFSTR(kIOPSVoltageKey));
		//CFShow(current_voltage);
	    if(current_voltage) {
	        CFRetain(current_voltage);

	        CFNumberGetValue(current_voltage, kCFNumberIntType, &current_voltage_value);
	        CFRelease(current_voltage);

             printf("current_voltage: %d\n", current_voltage_value/1000);
		}



	    printf("before release power_dictionary\n");
	    CFRelease(power_dictionary);
	    printf("after release power_dictionary\n");
	}
	return 0;
}
