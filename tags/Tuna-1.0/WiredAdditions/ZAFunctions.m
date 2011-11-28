/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

#import <ZankaAdditions/ZAFunctions.h>
#import <objc/objc-runtime.h>

IMP ZAReplaceMethodImplementationInClass(Class class, SEL selector, IMP newImp) {
	struct objc_method		*method;
	IMP						imp;
	
	method = class_getInstanceMethod(class, selector);
	
	if(!method) {
		NSLog(@"*** ZAReplaceMethodImplementationInClass: Could not find method implementation for %@ in class %@",
			  NSStringFromSelector(selector), NSStringFromClass(class));
		
		return NULL;
	}
	
	imp = method->method_imp;
	method->method_imp = newImp;
	
	return imp;
}



IMP ZAReplaceSelectorInClass(Class class, SEL selector, SEL newSelector) {
	struct objc_method		*method;
	
	method = class_getInstanceMethod(class, newSelector);
	
	if(!method) {
		NSLog(@"*** ZAReplaceSelectorInClass: Could not find method implementation for %@ in class %@",
			  NSStringFromSelector(newSelector), NSStringFromClass(class));
		
		return NULL;
	}
    
	return ZAReplaceMethodImplementationInClass(class, selector, method->method_imp);
}
