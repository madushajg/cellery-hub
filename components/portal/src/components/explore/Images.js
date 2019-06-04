/*
 * Copyright (c) 2019, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

import FormControl from "@material-ui/core/FormControl";
import Grid from "@material-ui/core/Grid";
import ImageList from "../common/ImageList";
import Input from "@material-ui/core/Input";
import InputAdornment from "@material-ui/core/InputAdornment";
import InputLabel from "@material-ui/core/InputLabel";
import MenuItem from "@material-ui/core/MenuItem";
import React from "react";
import SearchIcon from "@material-ui/icons/Search";
import Select from "@material-ui/core/Select";
import {withStyles} from "@material-ui/core/styles";
import * as PropTypes from "prop-types";

const styles = (theme) => ({
    formControl: {
        marginTop: theme.spacing(4),
        marginBottom: theme.spacing(1),
        minWidth: "100%"
    },
    placeholderIcon: {
        color: "#999999"
    }
});


class Images extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            sort: "most-popular"
        };
    }

    handleSortChange = (event) => {
        this.setState({
            sort: event.target.value
        });
    };

    render = () => {
        const {classes, data} = this.props;
        const {sort} = this.state;

        return (
            <React.Fragment>
                <Grid container>
                    <Grid item xs={12} sm={4} md={4}>
                        <FormControl className={classes.formControl}>
                            <InputLabel shrink htmlFor="search-label-placeholder"></InputLabel>
                            <Input
                                id="search"
                                startAdornment={
                                    <InputAdornment position="start">
                                        <SearchIcon className={classes.placeholderIcon}/>
                                    </InputAdornment>
                                }
                                placeholder="Search Image"
                            />
                        </FormControl>
                    </Grid>
                    <Grid item sm={5} md={5}>
                    </Grid>
                    <Grid item xs={12} sm={3} md={3}>
                        <form autoComplete="off">
                            <FormControl className={classes.formControl}>
                                <InputLabel shrink htmlFor="sort-label-placeholder">
                                    Sort
                                </InputLabel>
                                <Select
                                    value={sort}
                                    onChange={this.handleSortChange}
                                    input={<Input name="sort" id="sort-label-placeholder"/>}
                                    displayEmpty
                                    name="sort"
                                >
                                    <MenuItem value="most-popular">Most Popular</MenuItem>
                                    <MenuItem value="a-z">A-Z</MenuItem>
                                    <MenuItem value="updated">Recently Updated</MenuItem>
                                </Select>
                            </FormControl>
                        </form>
                    </Grid>
                    <Grid item xs={12} sm={12} md={12}>
                        <ImageList data={data}/>
                    </Grid>
                </Grid>
            </React.Fragment>
        );
    }

}

Images.propTypes = {
    classes: PropTypes.object.isRequired,
    data: PropTypes.arrayOf(PropTypes.object).isRequired
};

export default withStyles(styles)(Images);
