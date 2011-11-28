/* $Id$ */

/*
 *  Copyright (c) 2005-2009 Axel Andersson
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import "CPUDataSource.h"
#import "CPUSettings.h"

@implementation CPUData

@end



@implementation CPUDataSource

+ (CPUDataSource *)dataSource {
	static id	dataSource;
	
	if(!dataSource)
		dataSource = [[[self class] alloc] init];
	
	return dataSource;
}



- (id)init {
	NSTimer					*timer;
	host_basic_info_data_t	info;
    mach_msg_type_number_t  count;
	kern_return_t			err;
	NSUInteger				i;
	
	self = [super init];
	
	_machHost = mach_host_self();
	_machTask = mach_task_self();

	count = HOST_BASIC_INFO_COUNT;
	err = host_info(_machHost, HOST_BASIC_INFO, (host_info_t) &info, &count);
	
	if(err != KERN_SUCCESS) {
		NSLog(@"*** %@ host_info(): %s", self, mach_error_string(err));
		
		exit(1);
	}

	_numberOfCPUs = info.max_cpus;
	_data = (CPUData **) malloc(sizeof(CPUData *) * _numberOfCPUs);
	
	for(i = 0; i < _numberOfCPUs; i++)
		_data[i] = [[CPUData alloc] init];
	
	timer = [NSTimer scheduledTimerWithTimeInterval:[CPUSettings doubleForKey:CPUUpdateInterval]
											 target:self
										   selector:@selector(timer:)
										   userInfo:NULL
											repeats:YES];
	
	return self;
}



- (void)dealloc {
	NSUInteger		i;
	
	for(i = 0; i < _numberOfCPUs; i++)
		[_data[i] release];
	
	free(_data);

	[super dealloc];
}



#pragma mark -

- (void)clearHistory {
	NSUInteger		i;
	
	for(i = 0; i < _numberOfCPUs; i++) {
		memset(_data[i]->_userHistory, 0, sizeof(_data[i]->_niceHistory));
		memset(_data[i]->_systemHistory, 0, sizeof(_data[i]->_niceHistory));
		memset(_data[i]->_niceHistory, 0, sizeof(_data[i]->_niceHistory));
		
		_data[i]->_historyPosition = 0;
	}
}



#pragma mark -

- (void)timer:(NSTimer *)timer {
	CPUData							*data;
	processor_cpu_load_info_data_t  *cpu;
    mach_msg_type_number_t			count, ncpus;
	kern_return_t					err;
	NSUInteger						i, userTicks, systemTicks, niceTicks, idleTicks, totalTicks;

	err = host_processor_info(_machHost,
							  PROCESSOR_CPU_LOAD_INFO,
							  &ncpus,
							  (processor_info_array_t *) &cpu,
							  &count);
	
	if(err != KERN_SUCCESS) {
		NSLog(@"*** %@ host_processor_info(): %s", self, mach_error_string(err));
		
		return;
	}
	
	for(i = 0; i < ncpus; i++) {
		data				= _data[i];
		userTicks			= cpu[i].cpu_ticks[CPU_STATE_USER]   - data->_userTicks;
		systemTicks			= cpu[i].cpu_ticks[CPU_STATE_SYSTEM] - data->_systemTicks;
		niceTicks			= cpu[i].cpu_ticks[CPU_STATE_NICE]   - data->_niceTicks;
		idleTicks			= cpu[i].cpu_ticks[CPU_STATE_IDLE]   - data->_idleTicks;
		totalTicks			= userTicks + systemTicks + niceTicks + idleTicks;
		
		if(totalTicks > 0) {
			data->_user		= ((float) (userTicks))   / ((float) totalTicks);
			data->_system	= ((float) (systemTicks)) / ((float) totalTicks);
			data->_nice		= ((float) (niceTicks))   / ((float) totalTicks);
		} else {
			data->_user = data->_system = data->_nice = 0.0f;
		}
		
		data->_userTicks	= cpu[i].cpu_ticks[CPU_STATE_USER];
		data->_systemTicks	= cpu[i].cpu_ticks[CPU_STATE_SYSTEM];
		data->_niceTicks	= cpu[i].cpu_ticks[CPU_STATE_NICE];
		data->_idleTicks	= cpu[i].cpu_ticks[CPU_STATE_IDLE];

		data->_userHistory[data->_historyPosition]		= data->_user;
		data->_systemHistory[data->_historyPosition]	= data->_system;
		data->_niceHistory[data->_historyPosition]		= data->_nice;
		
		data->_historyPosition++;
		
		if(data->_historyPosition > CPUDataHistorySize)
			data->_historyPosition = 0;
}
	
	err = vm_deallocate(_machTask, (vm_address_t) cpu, count);

	if(err != KERN_SUCCESS)
		NSLog(@"*** %@ vm_deallocate(): %s", self, mach_error_string(err));
}

@end
