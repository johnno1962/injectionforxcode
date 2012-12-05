/*
 *  objsql.h - simple persistence layer for Objective-C classes
 *  ========
 *
 *  Created by John Holdsworth on 01/04/2009.
 *  Copyright 2009 © John Holdsworth. All Rights Reserved.
 *
 *  $Id: //depot/ObjCpp/objsql.h#41 $
 *  $DateTime: 2012/09/05 00:02:49 $
 *
 *  C++ classes to wrap up XCode classes for operator overload of
 *  useful operations such as access to NSArrays and NSDictionary
 *  by subscript or NSString operators such as + for concatenation.
 *
 *  This works as the Apple Objective-C compiler supports source
 *  which mixes C++ with objective C. To enable this: for each
 *  source file which will include/import this header file, select
 *  it in Xcode and open it's "Info". To enable mixed compilation,
 *  for the file's "File Type" select: "sourcecode.cpp.objcpp".
 *
 *  For bugs or ommisions please email objcpp@johnholdsworth.com
 *
 *  Home page for updates and docs: http://objcpp.johnholdsworth.com
 *
 *  If you find it useful please send a donation via paypal to account
 *  objcpp@johnholdsworth.com. Thanks.
 *
 *  License
 *  =======
 *
 *  You may make commercial use of this source in applications without
 *  charge but not sell it as source nor can you remove this notice from
 *  this source if you redistribute. You can make any changes you like
 *  to this code before redistribution but you must annotate them below.
 *
 *  For further details http://objcpp.johnholdsworth.com/license.html
 *
 *  THIS CODE IS PROVIDED “AS IS” WITHOUT WARRANTY OF ANY KIND EITHER
 *  EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 *  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 *  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
 *  WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
 *  THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING
 *  ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT
 *  OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED
 *  TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED 
 *  BY YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH 
 *  ANY OTHER PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN
 *  ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
 *
 */

#ifndef _objsql_h_
#define _objsql_h_
#ifdef __cplusplus
#import "objcpp.h"

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#define OOView UIView
#else
#define OOView NSView
#endif

@class OOView;

#define OOValueDictionary OODictionary<NSValue *>
#define cOOValueDictionary const OOValueDictionary &

#pragma mark OORecord abstract superclass for records

/**
 Superclass which can be used for all record classes to simplify interface to
 sqlite database. Any class can be a record class but subclasses of this class
 can use methods such as insert, update etc and be automatically registered 
 using [registerSubclassesOf:[OORecord class]].
 */

@interface OORecord : NSObject {
}

+ (id)insert OO_AUTORETURNS;
+ (id)insertWithParent:(id)parent OO_AUTORETURNS;

- (id)insert OO_RETURNS;
- (id)delete OO_RETURNS;
- (void)update;

- (void)indate;
- (void)upsert;

- (int)commit;
- (int)rollback;

+ (OOArray<id>)select;
+ (OOArray<id>)select:(cOOString)sql;
+ (OOArray<id>)selectRecordsRelatedTo:(id)record;

+ (id)record OO_AUTORETURNS;
- (OOArray<id>)select;

+ (int)importFrom:(OOFile &)file delimiter:(cOOString)delim;
+ (BOOL)exportTo:(OOFile &)file delimiter:(cOOString)delim;

- (void)bindToView:(OOView *)view delegate:(id)delegate;
- (void)updateFromView:(OOView *)view;

@end

#pragma mark OOMetaData instances represent a table in the database and it's record class

/**
 Internal class storing meta data about a class and its instance variables for
 constructing and binding data to an associated "sqlite" table.
 */

@interface OOMetaData : OORecord {
@public
	OOString tableTitle, tableName, recordClassName, keyColumns;
	OOStringArray ivars, columns, outcols, joinableColumns, tablesWithNaturalJoin,
		boxed, unbox, dates, archived, blobs, tocopy, indexes;
	OOStringDictionary types;
	OOString createTableSQL;
	Class recordClass;
}

+ (OOMetaData *)metaDataForClass:(Class)recordClass OO_RETURNS;
- initClass:(Class)aClass;

- (OOStringArray)naturalJoinTo:(cOOStringArray)to;
- (cOOValueDictionary)encode:(cOOValueDictionary)values;
- (cOOValueDictionary)decode:(cOOValueDictionary)values;

+ (OOArray<id>)import:(const OOArray<OODictionary<OOString> > &)nodes intoClass:(Class)recordClass;
+ (OOArray<id>)import:(cOOString)string intoClass:(Class)recordClass delimiter:(cOOString)delim;
+ (OOString)export:(const OOArray<id> &)array delimiter:(cOOString)delim;

+ (void)bindRecord:(id)record toView:(OOView *)view delegate:(id)delegate;
+ (void)updateRecord:(id)value fromView:(OOView *)view;

@end

#pragma mark OOTableCustomization method to alter relatoinship betweeh classes and database objects

/**
 Protocol which can be used to control aspects of the table associated with a particular class.
 */

@protocol OOTableCustomization

+ (NSString *)ooTableKey;
+ (NSString *)ooTableSql;
+ (NSString *)ooTableName;
+ (NSString *)ooTableTitle;
+ (NSString *)ooOrderBy;

+ (NSString *)ooConstraints;

- (void)awakeFromDB;

@end

@class OOAdaptor;

#pragma mark OODatabase is the low level interface to a particular database

/**
 Simple persistence class for Objective-C objects using a "sqlite" database. Instances a
 class are automatically bound to a table with the class name for insert, update and delete.
 
 A table with the same name as the class is created automatically when you perform any
 operation on instances of that class with columns corresponding to the instance variables
 of the class except those which begin with the character "_". If an instance variable 
 starts with an upper case letter it will be indexed.
 
 To update a record, fetch it and call the update: method passing it in as the argument to 
 save it's preious values. You can then modify it and call commit to update it's record.
 Delete operations on objects also accumulate and need to be commited to take effect.
 */

@interface OODatabase : NSObject {
	OODictionary<OOMetaData *> tableMetaDataByClassName;
	OOReference<OOAdaptor *> adaptor;
@public
	OOArray<OOValueDictionary > transaction, results;
	int errcode, updateCount;
	char *errmsg;
	OOString lastSQL;
}

+ (OODatabase *)sharedInstance;
+ (OODatabase *)sharedInstanceForPath:(cOOString)path;

+ (BOOL)exec:(cOOString)sql, ...;
+ (OOArray<id>)select:(cOOString)select intoClass:(Class)recordClass joinFrom:(id)parent;
+ (OOArray<id>)select:(cOOString)select intoClass:(Class)recordClass;
+ (OOArray<id>)select:(cOOString)select;

+ (int)insertArray:(const OOArray<id> &)objects;
+ (int)deleteArray:(const OOArray<id> &)objects;

+ (int)insert:(id)object;
+ (int)delete:(id)object;
+ (int)update:(id)object;

+ (int)indate:(id)object;
+ (int)upsert:(id)object;

+ (int)commit;
+ (int)rollback;
+ (int)commitTransaction;

- initPath:(cOOString)path;// __attribute__((objc_method_family(int)));

- (OOStringArray)registerSubclassesOf:(Class)recordSuperClass;
- (void)registerTableClassesNamed:(cOOStringArray)classes;

- (OOArray<OOMetaData *>)tablesRelatedByNaturalJoinFrom:(id)recordClass;
- (OOMetaData *)tableMetaDataForClass:(Class)recordClass OO_RETURNS;

- (BOOL)exec:(cOOString)sql, ...;
- (OOString)stringForSql:(cOOString)fmt, ...;
- (id)copyJoinKeysFrom:(id)parent to:(id)newChild;

- (OOArray<id>)select:(cOOString)select intoClass:(Class)recordClass joinFrom:(id)parent;
- (OOArray<id>)select:(cOOString)select intoClass:(Class)recordClass;
- (OOArray<id>)select:(cOOString)select;

- (long long)rowIDForRecord:(id)record;
- (long long)lastInsertRowID;

// all record modifications must be commited
- (int)insertArray:(const OOArray<id> &)objects;
- (int)deleteArray:(const OOArray<id> &)objects;

- (int)insert:(id)object;
- (int)delete:(id)object;
- (int)update:(id)object;

- (int)indate:(id)object;
- (int)upsert:(id)object;

- (int)commit;
- (int)commitTransaction;
- (int)rollback;

@end

#pragma mark OOTable records represent database object

/**
 record class for sqlite3's master table of database objects
 */

@interface OOTable {
	OOString type, name, tbl_name;
	int rootpage;
	OOString sql;
}
@end

/**
 implementation of -[UIView copy] for UITableViewCells
 */
@interface OOView(OOExtras)
- copyView;
@end

#pragma mark C++ interface to OODB

template <typename ETYPE>
oo_inline int OOArray<ETYPE>::fetch( id parent, cOOString sql ) {
	return *this = [[OODatabase sharedInstance] select:sql intoClass:[typeof *(ETYPE)0 class] joinFrom:parent];
}

/**
 Experimental even more operator overloaded interface to OODatabase.
 */

extern class OOOODatabase {
public:
	BOOL autocommit, autorelease;
	oo_inline OOOODatabase() {
		autocommit = YES;
		autorelease = NO;
	}
	oo_inline int commit() {
		return [OODatabase commit];
	}
	oo_inline id autowhatever( id record ) {
		if ( autocommit )
			commit();
		if ( autorelease )
			OO_RELEASE( record );
		return autorelease ? nil : record;
	}
	oo_inline id operator += ( id record ) {
		[[OODatabase sharedInstance] insert:record];
		return autowhatever( record );
	}
	oo_inline id operator -= ( id record ) {
		[[OODatabase sharedInstance] delete:record];
		return autowhatever( record );
	}
	oo_inline id operator *= ( id record ) {
		[[OODatabase sharedInstance] update:record];
		return record;
	}
	oo_inline OOArray<id> operator >> ( Class recordClass ) {
		return [recordClass select];
	}
///	oo_inline OOArray<id> operator >> ( id filter ) {
//		return [[filter class] selectRecordsRelatedTo:filter];
//	}
} OODB;

template <typename ETYPE>
inline OOArray<ETYPE> operator >> ( const OOOODatabase &oodb, OOArray<ETYPE> &arr ) {
	return arr.fetch();
}

#endif
#endif
