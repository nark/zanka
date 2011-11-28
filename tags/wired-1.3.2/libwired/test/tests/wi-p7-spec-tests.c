/* $Id$ */

/*
 *  Copyright (c) 2007 Axel Andersson
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

#include <wired/wired.h>

WI_TEST_EXPORT void						wi_test_p7_spec_builtin(void);
WI_TEST_EXPORT void						wi_test_p7_spec_string(void);


#ifdef WI_P7
static char								*_wi_test_p7_spec1 =
	"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
	"<p7:protocol xmlns:p7=\"http://www.zankasoftware.com/P7/Specification\""
	"			 xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\""
	"			 xsi:schemaLocation=\"http://www.zankasoftware.com/P7/Specification p7.xsd\""
	"			 name=\"test\""
	"			 version=\"1.0\">"
	"	<p7:fields>"
	"		<p7:field name=\"test.bool\" type=\"bool\" id=\"1000\" />"
	"		<p7:field name=\"test.enum\" type=\"enum\" id=\"1001\">"
	"			<p7:enum name=\"test.enum.1\" value=\"1\" />"
	"			<p7:enum name=\"test.enum.2\" value=\"2\" />"
	"			<p7:enum name=\"test.enum.3\" value=\"3\" />"
	"		</p7:field>"
	"		<p7:field name=\"test.int32\" type=\"int32\" id=\"1002\" />"
	"		<p7:field name=\"test.uint32\" type=\"uint32\" id=\"1003\" />"
	"		<p7:field name=\"test.int64\" type=\"int64\" id=\"1004\" />"
	"		<p7:field name=\"test.uint64\" type=\"uint64\" id=\"1005\" />"
	"		<p7:field name=\"test.double\" type=\"double\" id=\"1006\" />"
	"		<p7:field name=\"test.string\" type=\"string\" id=\"1007\" />"
	"		<p7:field name=\"test.uuid\" type=\"uuid\" id=\"1008\" />"
	"		<p7:field name=\"test.date\" type=\"date\" id=\"1009\" />"
	"		<p7:field name=\"test.data\" type=\"data\" id=\"1010\" />"
	"		<p7:field name=\"test.oobdata\" type=\"oobdata\" id=\"1011\" />"
	"	</p7:fields>"
	""
	"	<p7:messages>"
	"		<p7:message name=\"test\" id=\"1000\" />"
	"	</p7:messages>"
	"</p7:protocol>";
#endif



void wi_test_p7_spec_builtin(void) {
#ifdef WI_P7
	wi_p7_spec_t	*p7_spec;
	
	p7_spec = wi_p7_spec_builtin_spec();
	
	WI_TEST_ASSERT_NOT_NULL(p7_spec, "%m");
	
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_BOOL), WI_STR("bool"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_ENUM), WI_STR("enum"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_INT32), WI_STR("int32"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_UINT32), WI_STR("uint32"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_INT64), WI_STR("int64"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_UINT64), WI_STR("uint64"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_DOUBLE), WI_STR("double"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_STRING), WI_STR("string"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_UUID), WI_STR("uuid"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_DATE), WI_STR("date"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_DATA), WI_STR("data"), "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_type_name(p7_spec, WI_P7_OOBDATA), WI_STR("oobdata"), "");
	WI_TEST_ASSERT_NULL(wi_p7_spec_type_name(p7_spec, 2000), "");
	
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("bool")), (wi_p7_type_t) WI_P7_BOOL, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("enum")), (wi_p7_type_t) WI_P7_ENUM, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("int32")), (wi_p7_type_t) WI_P7_INT32, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("uint32")), (wi_p7_type_t) WI_P7_UINT32, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("int64")), (wi_p7_type_t) WI_P7_INT64, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("uint64")), (wi_p7_type_t) WI_P7_UINT64, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("double")), (wi_p7_type_t) WI_P7_DOUBLE, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("string")), (wi_p7_type_t) WI_P7_STRING, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("uuid")), (wi_p7_type_t) WI_P7_UUID, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("date")), (wi_p7_type_t) WI_P7_DATE, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("data")), (wi_p7_type_t) WI_P7_DATA, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("oobdata")), (wi_p7_type_t) WI_P7_OOBDATA, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_id(p7_spec, WI_STR("foo")), (wi_p7_type_t) WI_P7_SPEC_TYPE_ID_NULL, "");

	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_BOOL), 1U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_ENUM), 4U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_INT32), 4U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_UINT32), 4U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_INT64), 8U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_UINT64), 8U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_DOUBLE), 8U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_STRING), 0U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_UUID), 16U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_DATE), 26U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_DATA), 0U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, WI_P7_OOBDATA), 8U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_type_size(p7_spec, 2000), 0U, "");
#endif
}



void wi_test_p7_spec_string(void) {
#ifdef WI_P7
	wi_p7_spec_t	*p7_spec;
	
	p7_spec = wi_autorelease(wi_p7_spec_init_with_string(wi_p7_spec_alloc(), wi_string_with_cstring(_wi_test_p7_spec1)));
	
	WI_TEST_ASSERT_NOT_NULL(p7_spec, "%m");
	
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_name(p7_spec), WI_STR("test"), "");
	WI_TEST_ASSERT_EQUALS_WITH_ACCURACY(wi_p7_spec_version(p7_spec), 1.0, 0.001, "");
	
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_message_id(p7_spec, WI_STR("test")), 1000U, "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_message_name(p7_spec, 1000), WI_STR("test"), "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_message_id(p7_spec, WI_STR("foo")), (wi_uinteger_t ) WI_P7_SPEC_MESSAGE_ID_NULL, "");
	WI_TEST_ASSERT_NULL(wi_p7_spec_message_name(p7_spec, 2000), "");
	
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_id(p7_spec, WI_STR("test.bool")), 1000U, "");
	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_field_name(p7_spec, 1000), WI_STR("test.bool"), "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_id(p7_spec, WI_STR("foo")), (wi_uinteger_t ) WI_P7_SPEC_FIELD_ID_NULL, "");
	WI_TEST_ASSERT_NULL(wi_p7_spec_field_name(p7_spec, 2000), "");
	
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1000), (wi_p7_type_t) WI_P7_BOOL, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1001), (wi_p7_type_t) WI_P7_ENUM, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1002), (wi_p7_type_t) WI_P7_INT32, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1003), (wi_p7_type_t) WI_P7_UINT32, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1004), (wi_p7_type_t) WI_P7_INT64, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1005), (wi_p7_type_t) WI_P7_UINT64, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1006), (wi_p7_type_t) WI_P7_DOUBLE, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1007), (wi_p7_type_t) WI_P7_STRING, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1008), (wi_p7_type_t) WI_P7_UUID, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1009), (wi_p7_type_t) WI_P7_DATE, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1010), (wi_p7_type_t) WI_P7_DATA, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_field_type(p7_spec, 1011), (wi_p7_type_t) WI_P7_OOBDATA, "");

	WI_TEST_ASSERT_EQUAL_INSTANCES(wi_p7_spec_enum_name(p7_spec, 1001, 1), WI_STR("test.enum.1"), "");
	WI_TEST_ASSERT_NULL(wi_p7_spec_enum_name(p7_spec, 1001, 2000), "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_enum_value(p7_spec, 1001, WI_STR("test.enum.1")), 1U, "");
	WI_TEST_ASSERT_EQUALS(wi_p7_spec_enum_value(p7_spec, 1001, WI_STR("foo")), (wi_p7_enum_t) WI_P7_SPEC_ENUM_NULL, "");
#endif
}
